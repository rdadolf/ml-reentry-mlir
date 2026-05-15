#sparse = #sparse_tensor.encoding<{ map = (d0, d1) -> (d0 : dense, d1 : compressed), posWidth = 64, crdWidth = 64 }>
module {
  func.func @main(%arg0: tensor<3x3xf32, #sparse>, %arg1: tensor<3x4xf32>) -> tensor<3x4xf32> {
    %cst = arith.constant 0.000000e+00 : f32
    %0 = tensor.empty() : tensor<3x4xf32>
    %1 = linalg.fill ins(%cst : f32) outs(%0 : tensor<3x4xf32>) -> tensor<3x4xf32>
    %2 = linalg.matmul ins(%arg0, %arg1 : tensor<3x3xf32, #sparse>, tensor<3x4xf32>) outs(%1 : tensor<3x4xf32>) -> tensor<3x4xf32>
    return %2 : tensor<3x4xf32>
  }
}

