# Dynamo graph breaks on PyG convs (GAT, GCN, SAGE)

**Assessment: GREEN** across the project's full target conv set. Every
break observed on GAT and GCN traces back to the same family of PyG
self-loop utilities (`remove_self_loops`, `add_remaining_self_loops`,
`gcn_norm`) — all using `aten.nonzero` on a data-dependent edge mask.
PyG itself documents the workaround. SAGE has no breaks under defaults.
The graph that a backend (gnnc's `MLIRBackend` or anything else) receives
is **one unbroken FX graph** under `fullgraph=True` *or* the appropriate
PyG-recommended constructor flags (`add_self_loops=False`,
`normalize=False`) for the layers that have them.

The accompanying experiment also establishes the *architectural*
property that under default settings a backend is invoked once per FX
subgraph with no cross-subgraph context — so any cross-stage fusion
must be done within a single Dynamo trace, which means the trace must
be unbroken.

Source artifacts: [run.py](run.py), [dumps/](dumps/).
Pinned commits at characterization time:
[third_party/README.md](../../third_party/README.md).

## Question

Two questions:

1. **Where do graph breaks land on the project's target PyG convs**
   (GAT, GCN, SAGE) under `torch.compile`, what triggers them, and can
   they be eliminated?
2. **Can a backend see across graph breaks?** When Dynamo splits a
   function into N FX subgraphs, does the backend receive the whole
   function (N subgraphs in one call) or one subgraph at a time? If the
   latter, no backend optimization can span subgraphs — the only way to
   fuse across stages is to eliminate the breaks before they happen.

Both questions feed the v0 ingress design: the project plans
`gnnc.ingress.pyg_rewrites` as an **FX-level rewriter** that operates on
a single FX `GraphModule`. If any of these convs ship with unfixable
breaks under PyG's current API, that design is dead.

## Procedure

`run.py` exercises ten configurations across three conv types and two
questions:

| Module | Constructor args |
|---|---|
| A. single GATConv | `add_self_loops=True` (PyG default) |
| B. single GATConv | `add_self_loops=False` |
| C. 2-layer GAT (Cora-shaped, heads=8 + heads=1) | `add_self_loops=True` |
| D. 2-layer GAT | `add_self_loops=False` |
| E. single GCNConv | `add_self_loops=True, normalize=True` (PyG default) |
| F. single GCNConv | `add_self_loops=False, normalize=False` |
| G. 2-layer GCN | defaults |
| H. 2-layer GCN | compile-friendly |
| I. single SAGEConv | defaults |
| J. 2-layer SAGE | defaults |

For each: report `graph_count`, `graph_break_count`, `op_count`, and
break reasons via `torch._dynamo.explain`; cross-check whether
`fullgraph=True` produces a single graph.

For the visibility question: a `SpyBackend` records each
`GraphModule` it receives through the Dynamo backend API
(`(GraphModule, example_inputs) -> Callable`). Run on the GATConv case
(the most break-prone) with default `fullgraph=False` and with
`fullgraph=True`, on `add_self_loops=True` and `=False`. The visibility
result is structural — it generalizes to any model that breaks, so the
GCN/SAGE convs aren't re-tested.

Hardware: any CUDA box; the experiment is structural, not perf-tied.
Run via `source tools/env.sh && python experiments/dynamo-graph-breaks/run.py`.

## Findings

### Break inventory

| Config | `graph_count` | `graph_break_count` | `op_count` | `fullgraph=True` |
|---|---:|---:|---:|---|
| A. single GATConv, `self_loops=True` | 3 | 2 | 19 | ✅ single graph (26 ops) |
| B. single GATConv, `self_loops=False` | 1 | 0 | 15 | ✅ single graph |
| C. 2-layer GAT, `self_loops=True` | 6 | 5 | 39 | ✅ single graph |
| D. 2-layer GAT, `self_loops=False` | 1 | 0 | 31 | ✅ single graph |
| E. single GCNConv, defaults | 4 | 3 | 16 | ✅ single graph |
| F. single GCNConv, `self_loops=False, normalize=False` | 1 | 0 | 4 | ✅ single graph |
| G. 2-layer GCN, defaults | 6 | 5 | 22 | ✅ single graph |
| H. 2-layer GCN, compile-friendly | 1 | 0 | 9 | ✅ single graph |
| I. single SAGEConv, defaults | 1 | 0 | 6 | ✅ single graph |
| J. 2-layer SAGE, defaults | 1 | 0 | 13 | ✅ single graph |

Every break on GAT (A, C) is the same reason, at the same location:

```
reason: Dynamic shape operator
  Operator `aten.nonzero.default`'s output shape depends on input Tensor data.
  at site-packages/torch_geometric/utils/loop.py:113 in remove_self_loops
  at site-packages/torch_geometric/nn/conv/gat_conv.py:347 in forward
```

`remove_self_loops` builds a boolean mask `edge_index[0] != edge_index[1]`
and calls `.nonzero()` on it — the post-mask edge count is data-dependent,
so default Dynamo refuses to fold it and inserts a break. Two breaks per
GATConv layer (one for the mask, one for a Dynamo cache-key recompute on
the second use), scaling to 5 breaks across the 2-layer model.

GCN (E, G) breaks for the **same underlying cause** at different PyG
entry points: `add_remaining_self_loops` at
[`utils/loop.py:650`](file:///x/cache/venv/lib/python3.12/site-packages/torch_geometric/utils/loop.py) (called
inside `gcn_norm` at
[`nn/conv/gcn_conv.py:99`](file:///x/cache/venv/lib/python3.12/site-packages/torch_geometric/nn/conv/gcn_conv.py)).
Same `aten.nonzero`, same data-dependent edge mask. PyG's docs note the
same fix: set `add_self_loops=False, normalize=False` on the constructor
and apply the `GCNNorm` transform on the data side before `forward`.

SAGE (I, J) has **no breaks at all** under defaults. `SAGEConv` doesn't
add self-loops, doesn't normalize, and doesn't have an edge-softmax —
its forward decomposes cleanly into gather/matmul/scatter without
hitting any data-dependent ops.

**Uniform conclusion: `fullgraph=True` succeeds in every configuration**,
including all the breaking ones. The conv-set inventory is complete and
no per-op exceptions are needed.

PyG documents this:

> `remove_self_loops()` and `add_remaining_self_loops()` mask the given
> `edge_index`, leading to a device synchronization to compute its final
> output shape. ... PyG recommends augmenting graphs beforehand using
> transformations like `AddSelfLoops`, then setting `add_self_loops=False`
> in layer initialization.
> ([PyG compile docs](https://pytorch-geometric.readthedocs.io/en/2.6.1/advanced/compile.html))

**Key result:** under `fullgraph=True`, Dynamo traces the same code
without breaks, and `aten.nonzero` is **not in the resulting FX graph**
(verified by walking `gm.graph.nodes` in the visibility test). Whatever
mechanism Dynamo uses under fullgraph (symbolic shape inference or a
different lowering of the mask-then-nonzero pattern), the data-dependent
op gets traced through. The numerics still match the eager forward —
final output shape `(100, 32)` matches the eager run.

### Backend visibility

`SpyBackend` is invoked once per FX subgraph Dynamo emits:

| Configuration | Backend invocations |
|---|---|
| Default `fullgraph=False`, `self_loops=True` | **3 calls**: 11-node graph (`linear → mul → mul`), 5-node graph (`getitem → getitem` — the `edge_index[0] != edge_index[1]` mask), 43-node graph (everything downstream) |
| `fullgraph=True`, `self_loops=True` | **1 call**: 60-node, 26 call_function ops (whole GATConv as one graph) |
| `fullgraph=False`, `self_loops=False` | **1 call**: 46-node, 15 call_function ops |

The backend receives `(GraphModule, example_inputs) → Callable`. **There
is no parameter through which it can request sibling subgraphs.** Between
subgraphs, the runtime returns to the Python interpreter; subgraph N+1
is dispatched at a different Python call site. From the backend's POV
the existence of other subgraphs is invisible.

Concrete consequence: a backend handed `call 2` (43 nodes — the actual
SDDMM + softmax + SpMM math) **cannot** fuse it with the linear projection
in `call 0`. They live in different MLIR modules at different invocation
sites. No amount of backend cleverness can reach across that boundary.

## Strategy implication

Two facts together pin the v0 ingress design:

1. **The graph-break-elimination knob lives upstream of FX.** It is
   either `fullgraph=True` on the `torch.compile` invocation, or
   PyG's recommended constructor-flags + data-side transform pairing
   (`add_self_loops=False` paired with `AddSelfLoops`, and for GCN also
   `normalize=False` paired with `GCNNorm`). Both eliminate every break
   observed here, across GAT and GCN. SAGE needs neither.
   Neither is an FX rewrite — they configure the tracer, not the IR.
2. **The FX-rewrite layer (`gnnc.ingress.pyg_rewrites`) cannot fix the
   break.** By the time `pyg_rewrites` runs, the graph has either already
   been broken (and we see one shard with no context) or already been
   traced as one piece (and there is nothing about self-loops to rewrite —
   `aten.nonzero` is not in the graph). FX rewrites consume FX graphs;
   they do not configure how those graphs come into existence.

Concrete recipe for the gnnc ingress path:

- Set `fullgraph=True` on every `torch.compile` callsite that goes
  through `MLIRBackend` / `cpu_backend` / `gpu_backend`. Turns silent
  break-induced subgraph fragmentation into a loud error at trace time.
- Optionally also apply the data-side `AddSelfLoops` PyG transform and
  set `add_self_loops=False` on conv constructors during ingress
  preprocessing. Belt + suspenders: makes the trace clean even without
  `fullgraph=True`, and matches PyG's own recommendation.
- `pyg_rewrites` does its declared job (recognize the message-pass
  gather/scatter shape, rewrite to sparse-tensor IR) on the resulting
  clean single-graph trace.

## Verdict

**Project premise survives across the full target conv set.** GAT and
GCN ship with documented PyG issues that have documented workarounds;
SAGE has no issues at all. Under `fullgraph=True` (or PyG's recommended
constructor flags + data transforms), the FX graph delivered to a
backend is whole and unbroken for every conv the project targets —
exactly what the FX-rewrite-based ingress design requires.

## Recalibration of an earlier conclusion

The original [experiments/inductor-fusion](../inductor-fusion/) writeup
read the GATConv compile-unit count (3) as evidence that "Inductor cannot
fuse across SDDMM → softmax → SpMM." That conflated two layers:

- **3 compile units = Dynamo splitting GATConv into 3 FX subgraphs** —
  the graph-break issue characterized here. Fixable at the `torch.compile`
  invocation layer.
- **Kernel count within a compile unit = Inductor's intra-graph fusion
  decisions** — a different question, addressed in the [inductor-fusion
  followup](../inductor-fusion/README.md).

Once the graph-break issue is fixed (`fullgraph=True` or
`self_loops=False`), the compile-unit count drops to 1 and Inductor's
actual fusion behavior becomes the next question.

## Open follow-ups

- **Pooling ops.** PyG explicitly flags `global_mean_pool()` (when
  called without an explicit `batch_size`) as the same kind of break.
  Not in the current target set (node-classification benchmarks), but
  worth a sweep before graph-classification workloads enter scope.
- **GIN and other M2+ convs.** The verified conv set is GAT, GCN, SAGE.
  GIN (the project's stated v1+ target) hasn't been measured; expected
  to be clean (no self-loops, no normalize) but worth running before
  promising support.
- **Custom `MessagePassing` subclasses.** The break inventory here is for
  PyG-canonical convs. User-authored convs that do their own
  `scatter_*` calls may break in other places — not a problem until we
  promise to support them.
- **`torch.export` parity.** `torch.export` produces a single graph by
  construction (it errors on dynamism that Dynamo would silently break
  around). The [experiments/gatconv](../gatconv/) FX capture used
  `torch_mlir.fx.export_and_import` (which calls `torch.export`) and
  succeeded on GATConv with `self_loops=True` — so `torch.export` is
  another viable single-graph ingress path, equivalent in effect to
  `torch.compile(fullgraph=True)` but via a different mechanism.
