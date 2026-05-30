// Normally PyG emits a bespoke _sparse_mm call for the SPMM. This doesn't lower
// to the `torch` dialect, but because the sparse tensors correctly keep a
// sparse encoding, a normal matmul works fine. A rewrite pass remaps it.
//
// RUN: %gnnc %S/../../gnnc/examples/models/gcn.py --dialect raw | %FileCheck %s --check-prefix=CHECK,RAW
// RUN: %gnnc %S/../../gnnc/examples/models/gcn.py --dialect torch | %FileCheck %s --check-prefix=CHECK,TORCH

// CHECK: #sparse_tensor.encoding

// RAW: torch.aten._sparse_mm

// TORCH-NOT: torch.aten._sparse_mm
// TORCH: torch.aten.mm
