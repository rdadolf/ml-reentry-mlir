# Reference MLIR snapshots

Pinned MLIR from the gnnc pipeline (ingress -> `gnnc.conversion.tm_tensor_to_torch`
-> torch-mlir lowering), captured per model and dialect. These are regression fixtures:
after an LLVM / torch-mlir / PyG bump, regenerate and diff to detect emission
drift (same role as the `experiments/fx-sparsity` and `experiments/gatconv`
captures).

Regenerate any file with (phase → dialect: `import` → raw, `torch-legalize` →
torch, `linalg-lower` → linalg-on-tensors):

    gnnc-import gnnc/examples/models/<model>.py --stop-after <phase> > test/reference/<model>.<dialect>.mlir

## Coverage

| Model | raw | torch | linalg-on-tensors |
|---|---|---|---|
| GCN  | ✅ `gcn.raw.mlir` | ✅ `gcn.torch.mlir` | ✅ `gcn.linalg-on-tensors.mlir` |
| SAGE | ✅ `sage.raw.mlir` | ❌ | ❌ |

- `raw`: pristine FX import (`torch.aten._sparse_mm`, pre-rewrite).
- `torch`: after `gnnc.conversion.tm_tensor_to_torch` (`_sparse_mm` -> `aten.mm`) + torch-backend legalization.
- `linalg-on-tensors`: + lowering to linalg, with `#sparse_tensor.encoding` on the adjacency operand.

**SAGE `torch`/`linalg` are not yet legal:** stock `SAGEConv` emits
`torch.aten._sparse_mm.reduce` (it carries the mean-aggregation kind), which the
current rewrite set deliberately leaves alone — mapping a mean-reduce to a plain
matmul would be wrong.
