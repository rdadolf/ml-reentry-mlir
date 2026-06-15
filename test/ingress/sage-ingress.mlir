// SAGE emits `_sparse_mm.reduce(A, X, "mean")` for the neighbor mean-aggregation
// SpMM. The torch-dialect rewrite pipeline decomposes it into a plain `aten.mm`
// (SpMM-lowerable under the sparse encoding) plus a row-nnz divide. We assert
// the rewrite produces that shape, and that an empty-row guard (clamp_min) is
// in place so the divide matches PyTorch's `nnz=0 -> 0` semantics.
//
// RUN: gnnc-import %S/../../gnnc/examples/models/sage.py --stop-after import | FileCheck %s --check-prefix=CHECK,RAW
// RUN: gnnc-import %S/../../gnnc/examples/models/sage.py --stop-after torch-legalize | FileCheck %s --check-prefix=CHECK,TORCH

// CHECK: #sparse_tensor.encoding

// RAW: torch.aten._sparse_mm.reduce

// TORCH-NOT: torch.aten._sparse_mm.reduce
// TORCH: torch.aten.mm
// torch-mlir canonicalizes `clamp_min` to `clamp` with `none` max — same op.
// TORCH: torch.aten.clamp
// TORCH: torch.aten.div.Tensor
