# Ingress architecture: how PyG models reach sparse-tensor IR

The project's compile pipeline is

  PyG model → torch-mlir FX importer → torch dialect → linalg-on-tensors (sparse-tensor encoded) → `--sparsifier` → gpu-codegen

The "torch-mlir FX importer" step is where the structural problem sits.
PyG's `MessagePassing` framework emits its computation as scatter/gather
ops, and the FX → torch-dialect translation strips out the high-level
structure those ops are part of. By the time the IR reaches MLIR, the
sparsifier sees opaque int64 index tensors with no annotation of "this
index tensor was derived from `edge_index`" and no `sparse_tensor.encoding`
on anything.

The sparsifier needs the sparse-tensor encoding at the type level. Once
it's there, the downstream pipeline (linalg, `--sparsifier`, gpu-codegen)
works — see the m0/gat-gpu-codegen experiment for an empirical proof on the
exact IR shape we need. Without it, the IR is dense + scatter-based, and
lifting it back to sparse-tensor form at MLIR level is brittle
pattern-matching that breaks on any model variation.

## Where to intervene: pre-import FX rewriting

The information the sparsifier needs is present in the FX graph (before
torch-mlir translates it) but absent in the lowered MLIR. So the rewriter
belongs at the FX layer.

The package slot is reserved at `gnnc/ingress/pyg_rewrites` (currently
unimplemented; the `gnnc.ingress` `__init__.py` reserves it explicitly).
It operates on the FX graph PyG produces during `torch.export`: walks the
nodes, identifies subgraphs that match PyG's `MessagePassing` emission
patterns, replaces them with subgraphs that trace to sparse-tensor-encoded
MLIR.

Key architectural property: **the rewriter operates on PyG's FX output,
not on the user's model code, and not on PyG's library code.** A user
writing `GATConv(in, out, heads=...)` keeps writing exactly that. The
rewriter sees the FX subgraph emitted by GATConv (gather → leaky_relu →
scatter_amax → … → scatter_add) after FX export and replaces it; the user
model and the PyG installation are both untouched. No fork, no
monkey-patch, no model rewrite.

## Why FX is the right level

At the FX node level, the dataflow is fully explicit:

  edge_index → select → expand → view → scatter_add(values, indices=expanded, dim=0, into=zeros)

The provenance link "this scatter's index tensor came from `edge_index`"
is walkable backward through the FX graph. By contrast, after FX →
torch-dialect translation, the same scatter is `tm_tensor.scatter` over
an opaque `tensor<Ex2xi64>`; the structural connection to `edge_index`
is no longer in the IR, and the sparsifier has no way to recover it.

This is the standard ML-compiler frontend technique — XLA does this for
JAX, TVM does it for PyTorch, Inductor does it in pre-lowering passes.
Frontend-specific pattern recognition that runs **before** the
general-purpose backend gets the IR.

## The rewrite catalog

PyG's `MessagePassing` framework is small. Most graph convs in the
project's scope (GCN, SAGE, GAT) compile to combinations of about five
recurring FX patterns:

| PyG emission pattern | Sparse-tensor target |
|---|---|
| `gather(x, src) → scatter_add(by dst)` | `linalg.matmul` over a `sparse_tensor.encoding(CSR)`-typed adjacency |
| `gather(x, src) → scatter_reduce(reduce='mean', by dst)` | SpMM with row-normalized adjacency, or SpMM + per-row divide |
| `index_select(α_src, src) + index_select(α_dst, dst) + add + leaky_relu` | SDDMM as `linalg.generic` over the sparse adjacency structure |
| `scatter_reduce(reduce='amax') → index_select → sub → exp → scatter_add → add(ε) → div` (the `torch_geometric.utils.softmax` shape) | three `sparse_tensor.reduce` blocks: segmented max, segmented exp-sum, normalize |
| `gather(x, src) → mul by α → scatter_add(by dst)` (attention-weighted aggregation) | `linalg.generic` with `mulf + addf` reduction over sparse adjacency, attention values on edges |

These patterns are stable because PyG's `MessagePassing` framework
dictates the emission shape — individual conv layers (`GCNConv`,
`GATConv`, `SAGEConv`) override `message()`/`aggregate()`/`update()` hooks
but the framework controls how those compose into the final FX graph.

## Scope

In scope:

- GCN, SAGE, GAT, GIN — the project's target convs.
- Standard combinations of the five patterns above.
- Multi-head attention (the heads dimension is a parallel feature axis;
  doesn't change the pattern shape).

Out of scope:

- Custom `MessagePassing` subclasses with non-standard `aggregate()`
  implementations that don't compile to the recognized patterns. Behavior
  TBD: either reject at compile time or fall through to a dense path.
- Edge features. Adds an additional sparse-tensor dimension; would
  require a separate pattern.
- Models that bypass the `MessagePassing` framework entirely (writing
  scatter/gather by hand). These should already be in green-pattern form
  or close to it; the rewriter ignores them.

## Cost and risk

The rewriter is expected to be the largest single piece of M1/M2 work.
Risks worth tracking:

1. **PyG release cadence.** Patterns are stable across PyG versions in
   framework *semantics* but the specific aten ops emitted can shift
   between releases. Each PyG bump requires re-verifying the patterns
   against fresh FX dumps. Mitigation: the experiments/day-zero/fx-sparsity
   and experiments/m0/gatconv captures serve as regression fixtures —
   re-running them after a PyG upgrade detects emission drift.
2. **Pattern coverage gaps.** A model that almost matches a pattern but
   with one node out of place would silently fall through (or
   miscompile, depending on policy). Mitigation: detection logging at the
   rewriter, so unmatched MessagePassing subgraphs are visible at compile
   time rather than discovered as numerical disagreement.
3. **Validation.** The rewritten subgraph must be numerically equivalent
   to the original. Mitigation: the existing comparison harness pattern
   (PyG eager vs compiled output on a fixed input, within tolerance) is
   the gate.

## Bracketing characterizations

Two M0 experiments bracket this work:

- `experiments/m0/gatconv/` — captures what PyG-as-is gives us (the
  pre-rewrite IR shape). Verdict: `tm_tensor.scatter`-shaped, four
  scatter sites for a single GATConv layer.
- `experiments/m0/gat-gpu-codegen/` — proves the target IR shape
  (`sparse_tensor.reduce` blocks over CSR + `linalg.matmul` for SpMM
  pieces) compiles to native NVVM kernels with no library fallback.

The rewriter's job is to translate between these two shapes, on FX
graphs, before torch-mlir sees them.
