#map = affine_map<(d0, d1) -> (d0, d1)>
#map1 = affine_map<(d0, d1) -> (d1)>
#map2 = affine_map<(d0, d1) -> (d0)>
#map3 = affine_map<(d0, d1) -> (d0, 0)>
#sparse = #sparse_tensor.encoding<{ map = (d0, d1) -> (d0 : dense, d1 : compressed), posWidth = 64, crdWidth = 64 }>
module {
  func.func @main(%arg0: tensor<5x4xf32>, %arg1: tensor<5x5xf32, #sparse>) -> tensor<5x3xf32> {
    %cst = arith.constant 0.000000e+00 : f32
    %c0_i64 = arith.constant 0 : i64
    %cst_0 = arith.constant 0xFF800000 : f32
    %cst_1 = arith.constant dense_resource<torch_tensor_3_torch.float32> : tensor<3xf32>
    %cst_2 = arith.constant dense_resource<torch_tensor_3_8_torch.float32> : tensor<3x8xf32>
    %cst_3 = arith.constant dense_resource<torch_tensor_8_torch.float32> : tensor<8xf32>
    %cst_4 = arith.constant dense_resource<torch_tensor_8_4_torch.float32> : tensor<8x4xf32>
    %0 = tensor.empty() : tensor<4x8xf32>
    %transposed = linalg.transpose ins(%cst_4 : tensor<8x4xf32>) outs(%0 : tensor<4x8xf32>) permutation = [1, 0]
    %1 = tensor.empty() : tensor<5x8xf32>
    %2 = linalg.fill ins(%cst : f32) outs(%1 : tensor<5x8xf32>) -> tensor<5x8xf32>
    %3 = linalg.matmul ins(%arg0, %transposed : tensor<5x4xf32>, tensor<4x8xf32>) outs(%2 : tensor<5x8xf32>) -> tensor<5x8xf32>
    %4 = linalg.matmul ins(%arg1, %3 : tensor<5x5xf32, #sparse>, tensor<5x8xf32>) outs(%2 : tensor<5x8xf32>) -> tensor<5x8xf32>
    %5 = linalg.generic {indexing_maps = [#map, #map1, #map], iterator_types = ["parallel", "parallel"]} ins(%4, %cst_3 : tensor<5x8xf32>, tensor<8xf32>) outs(%1 : tensor<5x8xf32>) {
    ^bb0(%in: f32, %in_6: f32, %out: f32):
      %25 = arith.addf %in, %in_6 : f32
      linalg.yield %25 : f32
    } -> tensor<5x8xf32>
    %6 = linalg.generic {indexing_maps = [#map, #map], iterator_types = ["parallel", "parallel"]} ins(%5 : tensor<5x8xf32>) outs(%1 : tensor<5x8xf32>) {
    ^bb0(%in: f32, %out: f32):
      %25 = arith.cmpf ugt, %in, %cst : f32
      %26 = arith.select %25, %in, %cst : f32
      linalg.yield %26 : f32
    } -> tensor<5x8xf32>
    %7 = tensor.empty() : tensor<8x3xf32>
    %transposed_5 = linalg.transpose ins(%cst_2 : tensor<3x8xf32>) outs(%7 : tensor<8x3xf32>) permutation = [1, 0]
    %8 = tensor.empty() : tensor<5x3xf32>
    %9 = linalg.fill ins(%cst : f32) outs(%8 : tensor<5x3xf32>) -> tensor<5x3xf32>
    %10 = linalg.matmul ins(%6, %transposed_5 : tensor<5x8xf32>, tensor<8x3xf32>) outs(%9 : tensor<5x3xf32>) -> tensor<5x3xf32>
    %11 = linalg.matmul ins(%arg1, %10 : tensor<5x5xf32, #sparse>, tensor<5x3xf32>) outs(%9 : tensor<5x3xf32>) -> tensor<5x3xf32>
    %12 = linalg.generic {indexing_maps = [#map, #map1, #map], iterator_types = ["parallel", "parallel"]} ins(%11, %cst_1 : tensor<5x3xf32>, tensor<3xf32>) outs(%8 : tensor<5x3xf32>) {
    ^bb0(%in: f32, %in_6: f32, %out: f32):
      %25 = arith.addf %in, %in_6 : f32
      linalg.yield %25 : f32
    } -> tensor<5x3xf32>
    %13 = tensor.empty() : tensor<5xi64>
    %14 = linalg.fill ins(%c0_i64 : i64) outs(%13 : tensor<5xi64>) -> tensor<5xi64>
    %15 = tensor.empty() : tensor<5xf32>
    %16 = linalg.fill ins(%cst_0 : f32) outs(%15 : tensor<5xf32>) -> tensor<5xf32>
    %17:2 = linalg.generic {indexing_maps = [#map, #map2, #map2], iterator_types = ["parallel", "reduction"]} ins(%12 : tensor<5x3xf32>) outs(%16, %14 : tensor<5xf32>, tensor<5xi64>) {
    ^bb0(%in: f32, %out: f32, %out_6: i64):
      %25 = linalg.index 1 : index
      %26 = arith.index_cast %25 : index to i64
      %27 = arith.maximumf %in, %out : f32
      %28 = arith.cmpf ogt, %in, %out : f32
      %29 = arith.select %28, %26, %out_6 : i64
      linalg.yield %27, %29 : f32, i64
    } -> (tensor<5xf32>, tensor<5xi64>)
    %expanded = tensor.expand_shape %17#0 [[0, 1]] output_shape [5, 1] : tensor<5xf32> into tensor<5x1xf32>
    %18 = linalg.generic {indexing_maps = [#map, #map3, #map], iterator_types = ["parallel", "parallel"]} ins(%12, %expanded : tensor<5x3xf32>, tensor<5x1xf32>) outs(%8 : tensor<5x3xf32>) {
    ^bb0(%in: f32, %in_6: f32, %out: f32):
      %25 = arith.subf %in, %in_6 : f32
      linalg.yield %25 : f32
    } -> tensor<5x3xf32>
    %19 = linalg.generic {indexing_maps = [#map, #map], iterator_types = ["parallel", "parallel"]} ins(%18 : tensor<5x3xf32>) outs(%8 : tensor<5x3xf32>) {
    ^bb0(%in: f32, %out: f32):
      %25 = math.exp %in : f32
      linalg.yield %25 : f32
    } -> tensor<5x3xf32>
    %20 = tensor.empty() : tensor<5x1xf32>
    %21 = linalg.fill ins(%cst : f32) outs(%20 : tensor<5x1xf32>) -> tensor<5x1xf32>
    %22 = linalg.generic {indexing_maps = [#map, #map3], iterator_types = ["parallel", "reduction"]} ins(%19 : tensor<5x3xf32>) outs(%21 : tensor<5x1xf32>) {
    ^bb0(%in: f32, %out: f32):
      %25 = arith.addf %in, %out : f32
      linalg.yield %25 : f32
    } -> tensor<5x1xf32>
    %23 = linalg.generic {indexing_maps = [#map, #map], iterator_types = ["parallel", "parallel"]} ins(%22 : tensor<5x1xf32>) outs(%20 : tensor<5x1xf32>) {
    ^bb0(%in: f32, %out: f32):
      %25 = math.log %in : f32
      linalg.yield %25 : f32
    } -> tensor<5x1xf32>
    %24 = linalg.generic {indexing_maps = [#map, #map3, #map], iterator_types = ["parallel", "parallel"]} ins(%18, %23 : tensor<5x3xf32>, tensor<5x1xf32>) outs(%8 : tensor<5x3xf32>) {
    ^bb0(%in: f32, %in_6: f32, %out: f32):
      %25 = arith.subf %in, %in_6 : f32
      linalg.yield %25 : f32
    } -> tensor<5x3xf32>
    return %24 : tensor<5x3xf32>
  }
}

{-#
  dialect_resources: {
    builtin: {
      torch_tensor_3_torch.float32: "0x04000000000000000000000000000000",
      torch_tensor_3_8_torch.float32: "0x04000000396A913ECFF8DFBE2C9F8A3E1B3ABF3E4A59073FC1638D3EB7203BBFDD4BF5BE3CCFBC3E094A1E3E457D13BF1BBDD9BEB8DD313FA6CBFE3E94E0A4BEBA573EBE381B34BF777E59BC37610EBFDBD611BF7FAE26BD051AE33DCCDB9ABEC860E03E",
      torch_tensor_8_torch.float32: "0x040000000000000000000000000000000000000000000000000000000000000000000000",
      torch_tensor_8_4_torch.float32: "0x0400000085AAEABE86A8A6BE53EFFCBE208929BF2D56D3BE979A1B3F5E8CA13E5F78AF3E4952183D7B9CB9BE6E01F53D4D0429BF68CC02BF4CA4BABE876CE43E5D45D43EF68FA0BEF202D1BCB38BE73E12F5333FCBAF8F3EA6A2C33DF2BDF23E522BD5BE70ED063E65580CBF8AECFABEF205BBBE10D0A33EFD98913E5B74D6BEB8BF5A3E"
    }
  }
#-}
