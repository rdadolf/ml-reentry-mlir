# Ingress architecture (gnnc)

Compile pipeline:

  PyG model → `torch_mlir.fx.export_and_import` → torch dialect →
  linalg-on-tensors (sparse-encoded) → `--sparsifier` → gpu-codegen

This doc covers ingress — getting a PyG model into MLIR with sparse types
intact — and how to build it across the M1–M2 tickets. For what the MLIR
`sparse_tensor` dialect can and can't express, **`sparse-tensor-framework-reference.md`
is authoritative**; this doc defers all capability questions there and
focuses on the gnnc build.

## Committed path: sparse_csr adjacency + export

The adjacency enters as a `torch.sparse_csr_tensor`, built from `edge_index`
outside `forward` and passed as an argument; the model is traced with
`torch_mlir.fx.export_and_import`. This is the **only** path that preserves
`#sparse_tensor.encoding` on the MLIR function signature (ref, "PyG input
formats under torch.compile vs torch.export").

Consequence for gnnc: **ingress uses `torch.export` directly, not
Lighthouse's `MLIRBackend`.** `torch.compile`/Dynamo hard-refuses
sparse-tensor inputs, and Lighthouse is migrating its default ingress to
the compile-based backend. So gnnc owns an export-based ingress for
sparse-input models and does not route them through `MLIRBackend` /
`cpu_backend`. Plain-LongTensor models could use either path; the project
standardizes on export.

## What each model needs at ingress

| Model | Body after export | gnnc work at ingress |
|---|---|---|
| **GCN** | `torch.aten._sparse_mm(%adj, %x)` — direct | **None.** Feeds the verified SpMM lowering as-is. |
| **SAGE** | `_sparse_mm` + minor `crow_indices` extraction | **None** for aggregation; root-feature path is a small side branch. |
| **GAT** | encoding on signature, but body extracts `crow_indices`/`col_indices` and runs `[E]`-shaped gather/scatter | **`pyg_rewrites`** lifts that body to sparse-tensor ops. |

GCN/SAGE are end-to-end ready on this path: the sparse adjacency is consumed
as a sparse matmul with no rewrite. The entire rewriter problem is GAT.

## pyg_rewrites (GAT only)

Lives at `gnnc/ingress/pyg_rewrites` (slot reserved in
`gnnc.ingress.__init__`). Operates on the FX graph after `torch.export`,
before torch-mlir lowering. Rewrite target: GAT's
`(crow_indices, col_indices) → gather/scatter` body → a sparse-tensor
formulation of the per-edge stages.

The sparse-typed adjacency is already on the function signature, so the
rewrite has an explicit type anchor — it re-associates the `[E]`-shaped
per-edge ops with the sparse structure, rather than recovering sparsity
from opaque int64 arrays. Scope it to GAT's emission, not a universal
`MessagePassing` recognizer. The phase structure and exact op sequence to
match are in ref ("GAT forward — phase-by-phase") and DEV-139's structural
map.

## Build sequence

| Ticket | Ingress deliverable |
|---|---|
| **DEV-141** | GCN green path: `sparse_csr` adj + `torch.matmul(adj, X@W.T)` (write `torch.matmul` on the sparse operand, **not** `torch.sparse.mm` — the latter doesn't survive export with the encoding). Exported; encoding survives to linalg. The hand-shaped model is the minimal demonstrator; real `GCNConv` lands in the same `_sparse_mm` shape. |
| **DEV-142** | Real recipe (linalg → `--sparsifier` → LLVM); GCN correct vs PyG golden, CPU then GPU at arxiv. No new ingress work. |
| **DEV-143** | SAGE — reuses DEV-141/142 ingress; delta is reduction kind + concat, not ingress. |
| **DEV-144** | Same GCN lowered two ways (CSR-SpMM vs COO+segment-reduce) via `--recipe`. Format is a recipe choice, not an ingress choice — ingress emits the sparse adjacency once. (COO lowers directly on CPU; GPU needs `sparse_tensor.convert`→CSR; ref Tests 6/7.) |
| **DEV-145** | GAT unfused via `pyg_rewrites`: the **Design A floor** — per-stage `linalg.generic`/SpMM with `[E]`-shaped pre-aggregation, Inductor-like ~9 kernels. Verified achievable; does **not** depend on the SDDMM open question. |

Fusion (DEV-147 mechanism decision, DEV-149 implementation) is out of scope
for ingress and gated by the SDDMM-shape question (ref, "Open questions").
Ingress's job ends at producing legible, correct, unfused sparse-tensor IR.

## Risks (project-specific)

1. **Lighthouse export-path deprecation.** The sparse-input path depends on
   export-based ingress, which Lighthouse is moving away from. gnnc must
   keep its own export ingress and/or pin a Lighthouse commit; track the
   follow-up to Lighthouse PR #157. *No Linear ticket yet.*
2. **GAT fusion gate.** Whether GAT goes past Design A depends on
   SDDMM-shape legalization — two bounded experiments (ref, "Open questions"
   #1, #2). Run before committing DEV-147's mechanism.
3. **PyG emission drift.** `pyg_rewrites` matches a specific FX shape; each
   PyG bump needs re-verification against fresh dumps. The fx-sparsity /
   gatconv captures are the regression fixtures.
