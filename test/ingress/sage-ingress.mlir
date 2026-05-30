// Normally PyG emits a _sparse_mm call for the SPMM. This doesn't lower to
// MLIR's `torch` dialect, but because the sparse tensors are lowered correctly,
// it's functionally equivalent to just a mm. We add a rewrite pass to remap it.
//
// RUN: %gnnc %S/../../gnnc/examples/models/sage.py --dialect raw | %FileCheck %s --check-prefix=CHECK,RAW
// RUN: %gnnc %S/../../gnnc/examples/models/sage.py --dialect torch | %FileCheck %s --check-prefix=CHECK,TORCH

// XFAIL: *

// CHECK: #sparse_tensor.encoding

// RAW: torch.aten._sparse_mm.reduce

// TORCH-NOT: torch.aten._sparse_mm.reduce
// FIXME We still need a rewrite for this
