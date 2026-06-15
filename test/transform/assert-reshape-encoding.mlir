// The `gnnc-assert-reshape-encoding` Python pass, run through gnnc-opt, flags a
// reshape that drops `#sparse_tensor.encoding`. `not` flips the exit code, so
// the test passes iff the pass fired and failed.
//
// RUN: not gnnc-opt %s --pass gnnc-assert-reshape-encoding 2>&1 | FileCheck %s

// CHECK: tensor.expand_shape: input is sparse-encoded but output is dense

#sparse = #sparse_tensor.encoding<{ map = (d0, d1) -> (d0 : dense, d1 : compressed) }>

func.func @drops_encoding(%a: tensor<4x4xf32, #sparse>) -> tensor<4x1x4xf32> {
  %0 = tensor.expand_shape %a [[0, 1], [2]] output_shape [4, 1, 4]
       : tensor<4x4xf32, #sparse> into tensor<4x1x4xf32>
  return %0 : tensor<4x1x4xf32>
}
