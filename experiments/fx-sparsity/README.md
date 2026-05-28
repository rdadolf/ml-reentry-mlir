# Task 1: torch-mlir FX importer sparsity characterization

**Assessment: GREEN** (with one caveat — see "Strategy implication" below).

The full pipeline `PyG → torch_mlir.fx.export_and_import → torch backend
pipeline → torch-backend-to-linalg-on-tensors → mlir-opt --sparsifier → LLVM`
works end-to-end for a sparse matmul when sparsity is named at the model
input boundary. Sparse encodings are preserved through every stage. The v0
plan stands without budget changes.

Source artifacts: [run.py](run.py)
and [dumps/](dumps/).

Pinned commits at characterization time:
[third_party/README.md](../../third_party/README.md).

---

## Procedure

Three modules traced through `torch_mlir.fx.export_and_import` and lowered to
linalg-on-tensors, then optionally piped through `mlir-opt --sparsifier`:

| Module | Description |
|---|---|
| **c-matmul** | `a @ b`, dense × dense — sanity baseline. |
| **a-gcn** | One `GCNConv(in=4, out=2, add_self_loops=False, normalize=False, bias=False)` over a 3-node graph — the "ingest PyG as-is" path. |
| **b-sparse-mm** | `torch.matmul(csr, dense)` where `csr` is a `torch.sparse_csr_tensor(...)` passed as an input arg — the "explicit-sparse at the boundary" path. |

Three IR stages captured per module: raw torch dialect, post torch-to-linalg
lowering, post sparsifier (where applicable). Run script:
[experiments/fx-sparsity/run.py](run.py).

---

## Findings

### Module c-matmul (baseline)

Raw torch (`%0 = torch.aten.matmul %arg0, %arg1`, 6 lines) → linalg
(`linalg.matmul ins(...) outs(linalg.fill(0))`, 10 lines) → sparsifier
(141 lines of LLVM-with-sparse-runtime-calls — no sparse operands, but the
pipeline runs through cleanly to LLVM). Establishes that the toolchain is
healthy.

### Module a-gcn — "PyG as-is" path

**FX import: clean.** The message-passing structure is preserved verbatim
([a-gcn.1-raw-torch.mlir](dumps/a-gcn.1-raw-torch.mlir)):

```mlir
%1 = torch.aten.linear %arg0, %W, %none           // X · Wᵀ
%2 = torch.aten.select.int %edge_index, 0, 1      // dst-nodes
%3 = torch.aten.select.int %edge_index, 0, 0      // src-nodes
%4 = torch.aten.index_select %1, -2, %3           // gather src-features (messages)
%6 = torch.aten.view %2, [-1, 1]                  // dst → column
%8 = torch.aten.expand %6, [3, 2], false          // broadcast over feature dim
%10 = torch.aten.new_zeros %4, [3, 2], ...        // output buffer
%11 = torch.aten.scatter_add %10, 0, %8, %4       // segment-reduce by dst
```

`edge_index` is never densified. The adjacency stays as two `[E]`-shaped
integer tensors throughout — exactly the COO-without-the-vals representation.

**Torch-to-linalg: also clean, but produces `tm_tensor.scatter`.** The
backend pipeline lowers the `scatter_add` to a `tm_tensor.scatter` over a
`linalg.generic`-built (values, indices) pair
([a-gcn.2-linalg.mlir](dumps/a-gcn.2-linalg.mlir)):

```mlir
%11:3 = linalg.generic ... { yields (dst_idx_i64, col_i64, value_f32) tuples }
%inserted_slice_4 = ... 6×2 i64 indices tensor [dst, col] ...
%14 = tm_tensor.scatter
        ins(%11#2, %inserted_slice_4 : tensor<6xf32>, tensor<6x2xi64>)
        outs(%cst_0 : tensor<3x2xf32>) {
  ^bb0(%a: f32, %b: f32): tm_tensor.yield %15 = arith.addf %b, %a
}
```

The `(values: tensor<Nxf32>, indices: tensor<Nx2xi64>)` operands of
`tm_tensor.scatter` *are* a COO sparse representation. The structural
information needed to produce a sparse_tensor operation is fully present.

**Sparsifier: rejected.** `tm_tensor.scatter` lives in torch-mlir's
extension dialect; `mlir-opt` doesn't know it. Error from the sparsifier
pipeline:

```
error: Dialect `tm_tensor' not found for custom op 'tm_tensor.scatter'
```

This is the only thing blocking a pure-upstream lowering of the as-is path.
A targeted rewrite — pattern-match `tm_tensor.scatter(vals, idxs, init){addf}`
→ `sparse_tensor.assemble(vals, idxs)` + `linalg.generic` consuming the
assembled COO operand with a sparse encoding — is mechanical and bounded.
That puts the as-is path at **YELLOW** per the doc's strict definition.

But: we don't actually need this path, because option b is green.

### Module b-sparse-mm — "explicit-sparse at the boundary" path

**FX import: sparse encoding flows through the type system.** Passing a
`torch.sparse_csr_tensor` as an input arg makes the importer attach a
`sparse_tensor.encoding` attribute to the input vtensor type
([b-sparse-mm.1-raw-torch.mlir](dumps/b-sparse-mm.1-raw-torch.mlir)):

```mlir
#sparse = #sparse_tensor.encoding<{ map = (d0, d1) -> (d0 : dense, d1 : compressed),
                                    posWidth = 64, crdWidth = 64 }>
func.func @main(%arg0: !torch.vtensor<[3,3],f32,#sparse>,
                %arg1: !torch.vtensor<[3,4],f32>) -> !torch.vtensor<[3,4],f32> {
  %0 = torch.aten.matmul %arg0, %arg1 : ... -> ...
  return %0 : ...
}
```

Notes:
- `torch.matmul(csr, dense)` produces a plain `torch.aten.matmul`. Earlier
  tries with `torch.sparse.mm` produced a `torch.operator "torch.aten._sparse_mm"`
  extension-op that the standard pipeline marks illegal at lowering time.
  **Use plain `torch.matmul`** on sparse-typed operands — let the type carry
  the sparsity, not the op name.
- Constructing a `torch.sparse_csr_tensor` *inside* `forward()` fails during
  torch.export with `RuntimeError: Values and compressed tensor instance
  need to be on the same device` — a fake-tensor dispatch quirk for the
  `aten.sparse_compressed_tensor.comp_plain_value_size` meta. The
  workaround is simple: construct the CSR in user code and pass it as an
  argument.

**Torch-to-linalg: encoding survives.**
([b-sparse-mm.2-linalg.mlir](dumps/b-sparse-mm.2-linalg.mlir)):

```mlir
func.func @main(%arg0: tensor<3x3xf32, #sparse>,
                %arg1: tensor<3x4xf32>) -> tensor<3x4xf32> {
  %2 = linalg.matmul ins(%arg0, %arg1 : tensor<3x3xf32, #sparse>, tensor<3x4xf32>)
                     outs(%1 : tensor<3x4xf32>) -> tensor<3x4xf32>
  return %2
}
```

This is exactly the shape the sparsifier consumes.

**Sparsifier: end-to-end clean.** `mlir-opt --sparsifier` produces 166 lines
of LLVM IR with sparse runtime calls (`@sparseCoordinates64`,
`@sparsePositions64`, `@sparseValuesF32`, etc.) — the standard upstream
sparse-runtime-library code path
([b-sparse-mm.3-sparsifier.mlir](dumps/b-sparse-mm.3-sparsifier.mlir)).

---

## Strategy implication

The "ingest PyG as-is" path is yellow; the "name sparsity at the boundary"
path is green. We don't need to ingest PyG as-is — the project summary
already plans to use Python-level rewrites at ingress
([project-summary.md:54-56](project-summary.md#L54-L56)). Concretely, for
v0:

1. At ingress, rewrite the model so the adjacency is a
   `torch.sparse_csr_tensor` (or COO) constructed from `edge_index` *outside*
   `forward`, then passed in as an argument.
2. The body of `forward` then expresses message-passing as plain
   `torch.matmul(adj, transformed_features)` (or equivalent) on the
   sparse-typed operand.
3. FX-import → torch backend → linalg-on-tensors → sparsifier → LLVM.

This matches the project's stated v0 ("no `gnn.*` dialect — Python-level
rewrites land directly in `linalg.generic` with sparse encodings, exercising
only upstream MLIR") and unblocks week-1 work without needing a custom
tm_tensor → sparse_tensor adapter.

---

## Open follow-ups

- **GAT (week 3) is unverified.** GAT introduces edge-softmax and per-edge
  attention coefficients. These don't reduce to `csr @ dense` and may not
  fit the "name sparsity at the boundary" template as cleanly. Re-run this
  characterization on a single `GATConv` layer before week 3 starts.
- **`torch.sparse.mm` is dead-end-ish.** It becomes a `torch.operator
  "torch.aten._sparse_mm"` that the standard pipeline rejects. Use plain
  `torch.matmul` on sparse-typed operands instead. Worth a comment in the
  v0 recipe code so this doesn't get rediscovered.
- **The tm_tensor → sparse_tensor rewrite is still worth understanding,**
  even if we don't use it in v0. If a future ingress path needs to ingest
  PyG-style scatter-add directly (e.g., because some message function
  doesn't decompose into a clean `adj @ x`), the rewrite would unblock it.
  Half-week budget per the original task estimate; defer until needed.
- **OGB load triggers `torch.load` weights_only=True rejection.** Already
  fixed at commit `ee3da8c` via `gnnc/_torch_load_compat.py`. Noted here
  because it can bite anyone running these experiments outside the harness.
