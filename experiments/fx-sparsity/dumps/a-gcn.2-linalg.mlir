#map = affine_map<(d0, d1) -> (d0)>
#map1 = affine_map<(d0, d1) -> (d0, d1)>
#map2 = affine_map<(d0) -> (d0, 0)>
#map3 = affine_map<(d0) -> (d0)>
module {
  func.func @main(%arg0: tensor<3x4xf32>, %arg1: tensor<2x3xi64>) -> tensor<3x2xf32> {
    %cst = arith.constant 0.000000e+00 : f32
    %c0_i64 = arith.constant 0 : i64
    %c2 = arith.constant 2 : index
    %c3 = arith.constant 3 : index
    %cst_0 = arith.constant dense<0.000000e+00> : tensor<3x2xf32>
    %cst_1 = arith.constant dense_resource<torch_tensor_2_4_torch.float32> : tensor<2x4xf32>
    %0 = tensor.empty() : tensor<4x2xf32>
    %transposed = linalg.transpose ins(%cst_1 : tensor<2x4xf32>) outs(%0 : tensor<4x2xf32>) permutation = [1, 0] 
    %1 = tensor.empty() : tensor<3x2xf32>
    %2 = linalg.fill ins(%cst : f32) outs(%1 : tensor<3x2xf32>) -> tensor<3x2xf32>
    %3 = linalg.matmul ins(%arg0, %transposed : tensor<3x4xf32>, tensor<4x2xf32>) outs(%2 : tensor<3x2xf32>) -> tensor<3x2xf32>
    %extracted_slice = tensor.extract_slice %arg1[1, 0] [1, 3] [1, 1] : tensor<2x3xi64> to tensor<1x3xi64>
    %collapsed = tensor.collapse_shape %extracted_slice [[0, 1]] : tensor<1x3xi64> into tensor<3xi64>
    %extracted_slice_2 = tensor.extract_slice %arg1[0, 0] [1, 3] [1, 1] : tensor<2x3xi64> to tensor<1x3xi64>
    %collapsed_3 = tensor.collapse_shape %extracted_slice_2 [[0, 1]] : tensor<1x3xi64> into tensor<3xi64>
    %4 = linalg.generic {indexing_maps = [#map, #map1], iterator_types = ["parallel", "parallel"]} ins(%collapsed_3 : tensor<3xi64>) outs(%1 : tensor<3x2xf32>) {
    ^bb0(%in: i64, %out: f32):
      %15 = arith.index_cast %in : i64 to index
      %16 = linalg.index 1 : index
      %extracted = tensor.extract %3[%15, %16] : tensor<3x2xf32>
      linalg.yield %extracted : f32
    } -> tensor<3x2xf32>
    %5 = tensor.empty() : tensor<3x2xi64>
    %6 = linalg.generic {indexing_maps = [#map, #map1], iterator_types = ["parallel", "parallel"]} ins(%collapsed : tensor<3xi64>) outs(%5 : tensor<3x2xi64>) {
    ^bb0(%in: i64, %out: i64):
      linalg.yield %in : i64
    } -> tensor<3x2xi64>
    %7 = tensor.empty() : tensor<6x1xi64>
    %8 = linalg.fill ins(%c0_i64 : i64) outs(%7 : tensor<6x1xi64>) -> tensor<6x1xi64>
    %9 = tensor.empty() : tensor<6xf32>
    %10 = linalg.fill ins(%cst : f32) outs(%9 : tensor<6xf32>) -> tensor<6xf32>
    %11:3 = linalg.generic {indexing_maps = [#map2, #map2, #map3], iterator_types = ["parallel"]} outs(%8, %8, %10 : tensor<6x1xi64>, tensor<6x1xi64>, tensor<6xf32>) {
    ^bb0(%out: i64, %out_5: i64, %out_6: f32):
      %15 = linalg.index 0 : index
      %16 = arith.remsi %15, %c2 : index
      %17 = arith.divsi %15, %c2 : index
      %18 = arith.remsi %17, %c3 : index
      %extracted = tensor.extract %6[%18, %16] : tensor<3x2xi64>
      %extracted_7 = tensor.extract %4[%18, %16] : tensor<3x2xf32>
      %19 = arith.index_cast %16 : index to i64
      linalg.yield %extracted, %19, %extracted_7 : i64, i64, f32
    } -> (tensor<6x1xi64>, tensor<6x1xi64>, tensor<6xf32>)
    %12 = tensor.empty() : tensor<6x2xi64>
    %13 = linalg.fill ins(%c0_i64 : i64) outs(%12 : tensor<6x2xi64>) -> tensor<6x2xi64>
    %inserted_slice = tensor.insert_slice %11#0 into %13[0, 0] [6, 1] [1, 1] : tensor<6x1xi64> into tensor<6x2xi64>
    %inserted_slice_4 = tensor.insert_slice %11#1 into %inserted_slice[0, 1] [6, 1] [1, 1] : tensor<6x1xi64> into tensor<6x2xi64>
    %14 = tm_tensor.scatter {dimension_map = array<i64: 0, 1>} unique_indices(false) ins(%11#2, %inserted_slice_4 : tensor<6xf32>, tensor<6x2xi64>) outs(%cst_0 : tensor<3x2xf32>) {
    ^bb0(%arg2: f32, %arg3: f32):
      %15 = arith.addf %arg3, %arg2 : f32
      tm_tensor.yield %15 : f32
    } -> tensor<3x2xf32>
    return %14 : tensor<3x2xf32>
  }
}

{-#
  dialect_resources: {
    builtin: {
      torch_tensor_2_4_torch.float32: "0x0400000070BFB5BD4C7B873EACBB9ABE704849BEB89174BF528B29BFE80ED3BE00BB173D"
    }
  }
#-}

