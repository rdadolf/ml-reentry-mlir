# Inductor fusion on PyG GATConv

**Assessment: YELLOW** — Inductor fuses *within* GAT stages but cannot
cross the segmented-reduction boundary or the cross-layer boundary.
Given an unbroken FX graph, Inductor emits **7 Triton kernels + 1 cuBLAS
`mm`** per GATConv layer, scaling exactly 2× to a 2-layer GAT. This
leaves a real residual fusion opportunity for sparse-tensor IR — but
narrower than the original framing implied.

Two scripts:

- [run.py](run.py) — original characterization. Asks "how many Triton
  kernels does Inductor emit on GATConv?" using PyG defaults
  (`add_self_loops=True`), which under default `torch.compile` produces
  3 FX subgraphs from the `remove_self_loops` graph break.
- [run-followup.py](run-followup.py) — measures Inductor's actual
  intra-graph fusion in isolation by giving it the unbroken graph
  (`add_self_loops=False` + `fullgraph=True`). 1 compile unit, then
  count kernels.

Dumps: original under [dumps/](dumps/), follow-up under
[dumps/followup/](dumps/followup/).

Pinned commits at characterization time:
[third_party/README.md](../../third_party/README.md). Hardware: RTX 4070
(sm_89, Ada Lovelace).

## Recalibration of the original conclusion

The original `run.py` reported 3 compile units and read this as
"hypothesis confirmed, Inductor treats each stage as a separate launch."
That conflated two distinct effects:

1. **3 compile units** — Dynamo splitting GATConv into 3 disjoint FX
   subgraphs at PyG's `remove_self_loops`. This is the graph-break
   issue characterized in
   [experiments/dynamo-graph-breaks](../dynamo-graph-breaks/). Eliminable
   via `fullgraph=True` or `add_self_loops=False`.
2. **Triton kernels per compile unit** — Inductor's intra-graph fusion
   decisions. Not the same question.

The follow-up isolates (2). Once Dynamo delivers a single unbroken FX
graph, Inductor still produces multiple GPU kernels because its
scheduler treats segmented reductions (`scatter_reduce`, `scatter_add`)
as memory-fence boundaries.

The original `run.py` is preserved as a historical artifact of how the
question was first asked; this README treats the follow-up as the
authoritative measurement.

## Findings — unbroken-graph baseline

From `run-followup.py` (PyG libs masked, `fullgraph=True`,
`add_self_loops=False`):

| Module | Compile units | Triton kernels | extern_kernels |
|---|---:|---:|---|
| 1-layer GATConv | 1 | 7 | 1 × `mm` (cuBLAS) |
| 2-layer GAT (h=8 / h=1) | 1 | 14 | 2 × `mm` |

**2-layer / 1-layer kernel ratio = 2.00 exactly.** No cross-layer fusion.

### What each kernel covers (1-layer GATConv)

Mapping kernel → GAT pipeline stage, from the `# Topologically Sorted
Source Nodes:` annotations Inductor emits:

| Kernel | Stage |
|---|---|
| extern `mm` | `Wx` (dense GEMM via cuBLAS) |
| 0 | α_src / α_dst precompute (`mul` + `sum.dim_IntList` over heads) |
| 1 | SDDMM (`index_select + add + leaky_relu`) **fused with** segmented-amax for softmax stability |
| 2 | SDDMM redo — Inductor materializes `α` once for the amax path and again for the denominator path (this is recomputation, not a re-read) |
| 3 | Segmented `scatter_add` for softmax denominator |
| 4 + 5 | Weighted SpMM aggregation. Inductor uses a split-reduction layout: kernel 4 produces partial sums, kernel 5 combines |
| 6 | Final reshape (`view` collapsing `[N, H, D] → [N, H·D]`) |

### What Inductor IS fusing well

- **Intra-stage chains.** Kernel 1 fuses `index_select → add →
  leaky_relu → scatter_reduce(amax)` — that is SDDMM + segmented-max
  collapsed into one kernel.
- **Adjacent reductions.** The amax init and accumulate share kernel 1.
- **Dense GEMM dispatch.** `Wx` correctly goes to cuBLAS rather than
  being emitted as Triton — high-value punt.

### What Inductor is NOT fusing (the residual opportunity)

Three structurally distinct boundaries:

1. **Segmented-reduction boundary.** Every `scatter_add` /
   `scatter_reduce` is its own kernel because Inductor's scheduler
   treats them as memory-fence ops over dense `[N, H, D]` buffers. A
   sparse-tensor IR formulation can express SDDMM + softmax + SpMM as
   a single fused loop nest over a sparse adjacency, with the
   per-edge intermediates living in registers/shared memory rather
   than DRAM.
2. **Redundant SDDMM.** Kernels 1 and 2 each recompute the SDDMM
   (`α_src + α_dst + leaky_relu`) because `α` is needed twice in the
   edge-softmax. A unified sparse expression computes it once.
3. **Cross-layer fusion.** Zero. `conv1`'s output `[N, H·D]` tensor
   is fully materialized to DRAM before `conv2` reads it.

### Dense-buffer cost (intermediates, not outputs)

Each kernel boundary that involves `scatter_*` allocates a `new_zeros_*`
tensor of shape `[N, H, D]` (for the SpMM output) or `[N, H]` (for the
softmax denominator) and scatters into it. The output buffers exist in
both stacks; the meaningful avoidance — conditional on fusing the loop
nest — is the **edge-sized intermediates** Inductor must commit to
DRAM between kernels:

- `α[E, H]` — written after kernel 1, read by kernel 3
- `α_normalized[E, H]` — written after kernel 3, read by kernel 4
- `weighted_messages[E, H, D]` — written inside the SpMM pipeline

At toy scale (500 edges) these are negligible. At Cora (~10K edges × 8
heads × 8 dim = ~640K floats per intermediate) they are still small. At
OGB-Arxiv (~1.2M edges × 8 × 8 ≈ ~76M floats, ~300MB per intermediate)
they matter. At OGB-Papers (~100M edges) they dominate.

## Strategy implication

The deliverable framing for gnnc's fusion work should be:

| Deliverable | Status |
|---|---|
| Reduce GPU kernel launches by collapsing scatter-reduce boundaries via sparse-tensor codegen | Real. ~7 → ~3 launches per GATConv layer plausible (needs measurement post-implementation). |
| Avoid materializing edge-sized intermediates between segmented stages | Real, **conditional on** writing the pipeline as a fused sparse `linalg.generic` (not automatic from "use sparse_tensor") |
| Cross-layer fusion (conv1 → activation → conv2) | Open research, untouched by Inductor and by naive sparsifier; sparse-tensor IR + linalg fusion *might* extend across layer boundaries, unverified |
| Generalize the recipe to GIN, SAGE, heterogeneous, masked variants | Real — this is the platform argument that justifies the compiler rather than per-op kernel authoring |
| GPU codegen via MLIR sparse path rather than Triton | True but a means, not an end |

What we *should not* claim:

- "Inductor cannot fuse the GATConv pipeline." It fuses intra-stage well
  and emits 7 launches per layer rather than per-stage launches. The
  pitch is the residual boundaries (segmented reductions, cross-layer),
  not absolute kernel count.
- "Sparse-tensor codegen automatically achieves the fusion." It requires
  schedule authorship — the message-pass has to be expressed as a fused
  sparse `linalg.generic`, which is the deliverable, not a free
  property of using the `sparse_tensor` dialect.

## Reproducing

```bash
source tools/env.sh
# Original characterization (PyG defaults — produces the 3-compile-unit
# Dynamo-broken case, dumps to dumps/):
python experiments/inductor-fusion/run.py --disable-libs
# Follow-up (unbroken graph, dumps to dumps/followup/):
python experiments/inductor-fusion/run-followup.py
```

`run-followup.py` masks PyG helper libs at import time and forces
`fullgraph=True` — no flags needed.

## Open follow-ups

- **Realistic-scale measurement.** The kernel count is structural and
  shouldn't change with scale, but the relative cost of each kernel
  (and the absolute DRAM-intermediate cost) does. Cora (2.7K nodes /
  10K edges) and OGB-Arxiv (169K / 1.2M) would each give us a meaningful
  data point; OGB-Papers (111M / ~3B edges) is where the
  edge-sized-intermediate argument is decisive.
- **dgNN / DF-GNN comparison.** dgNN reports sub-5ms GATConv forwards
  on similar workloads via a single fused kernel; the gap to our
  Inductor measurement is the headroom gnnc claims. The
  [pyg-baseline](../pyg-baseline/README.md) writeup quantifies this
  gap as a back-of-envelope ~3× on ogbn-arxiv; concrete A/B remains
  unmeasured.
- **GCN, SAGE.** Both are simpler than GAT (no edge-softmax, no
  attention). Inductor's fusion is likely *better* on them (fewer
  segmented-reduction boundaries to cross), which would compress
  gnnc's relative win. Worth measuring before quoting "we beat
  Inductor on GNNs" generically.
