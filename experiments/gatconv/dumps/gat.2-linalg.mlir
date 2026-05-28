#map = affine_map<(d0, d1, d2) -> (d0, d1, d2)>
#map1 = affine_map<(d0, d1, d2) -> (0, d1, d2)>
#map2 = affine_map<(d0, d1, d2) -> (d0, d1)>
#map3 = affine_map<(d0, d1) -> (d0)>
#map4 = affine_map<(d0, d1) -> (d0, d1)>
#map5 = affine_map<(d0, d1) -> ()>
#map6 = affine_map<(d0) -> (d0, 0)>
#map7 = affine_map<(d0) -> (d0)>
#map8 = affine_map<(d0, d1, d2) -> (d0)>
#map9 = affine_map<(d0, d1, d2) -> (d0, d1, 0)>
module {
  func.func @main(%arg0: tensor<3x4xf32>, %arg1: tensor<2x3xi64>) -> tensor<3x4xf32> {
    %cst = arith.constant 0xFF800000 : f32
    %cst_0 = arith.constant 0.000000e+00 : f32
    %c0_i64 = arith.constant 0 : i64
    %c2 = arith.constant 2 : index
    %c3 = arith.constant 3 : index
    %cst_1 = arith.constant dense<0.000000e+00> : tensor<3x2x2xf32>
    %cst_2 = arith.constant dense<0.000000e+00> : tensor<3x2xf32>
    %cst_3 = arith.constant dense_resource<torch_tensor_4_4_torch.float32> : tensor<4x4xf32>
    %cst_4 = arith.constant dense_resource<torch_tensor_1_2_2_torch.float32> : tensor<1x2x2xf32>
    %cst_5 = arith.constant dense_resource<torch_tensor_1_2_2_torch.float32_1> : tensor<1x2x2xf32>
    %cst_6 = arith.constant 2.000000e-01 : f64
    %cst_7 = arith.constant 9.9999999999999997E-17 : f64
    %cst_8 = arith.constant dense<0.000000e+00> : tensor<f32>
    %0 = tensor.empty() : tensor<4x4xf32>
    %transposed = linalg.transpose ins(%cst_3 : tensor<4x4xf32>) outs(%0 : tensor<4x4xf32>) permutation = [1, 0] 
    %1 = tensor.empty() : tensor<3x4xf32>
    %2 = linalg.fill ins(%cst_0 : f32) outs(%1 : tensor<3x4xf32>) -> tensor<3x4xf32>
    %3 = linalg.matmul ins(%arg0, %transposed : tensor<3x4xf32>, tensor<4x4xf32>) outs(%2 : tensor<3x4xf32>) -> tensor<3x4xf32>
    %expanded = tensor.expand_shape %3 [[0], [1, 2]] output_shape [3, 2, 2] : tensor<3x4xf32> into tensor<3x2x2xf32>
    %4 = tensor.empty() : tensor<3x2x2xf32>
    %5 = linalg.generic {indexing_maps = [#map, #map1, #map], iterator_types = ["parallel", "parallel", "parallel"]} ins(%expanded, %cst_4 : tensor<3x2x2xf32>, tensor<1x2x2xf32>) outs(%4 : tensor<3x2x2xf32>) {
    ^bb0(%in: f32, %in_19: f32, %out: f32):
      %50 = arith.mulf %in, %in_19 : f32
      linalg.yield %50 : f32
    } -> tensor<3x2x2xf32>
    %6 = tensor.empty() : tensor<3x2xf32>
    %7 = linalg.fill ins(%cst_0 : f32) outs(%6 : tensor<3x2xf32>) -> tensor<3x2xf32>
    %8 = linalg.generic {indexing_maps = [#map, #map2], iterator_types = ["parallel", "parallel", "reduction"]} ins(%5 : tensor<3x2x2xf32>) outs(%7 : tensor<3x2xf32>) {
    ^bb0(%in: f32, %out: f32):
      %50 = arith.addf %in, %out : f32
      linalg.yield %50 : f32
    } -> tensor<3x2xf32>
    %9 = linalg.generic {indexing_maps = [#map, #map1, #map], iterator_types = ["parallel", "parallel", "parallel"]} ins(%expanded, %cst_5 : tensor<3x2x2xf32>, tensor<1x2x2xf32>) outs(%4 : tensor<3x2x2xf32>) {
    ^bb0(%in: f32, %in_19: f32, %out: f32):
      %50 = arith.mulf %in, %in_19 : f32
      linalg.yield %50 : f32
    } -> tensor<3x2x2xf32>
    %10 = linalg.generic {indexing_maps = [#map, #map2], iterator_types = ["parallel", "parallel", "reduction"]} ins(%9 : tensor<3x2x2xf32>) outs(%7 : tensor<3x2xf32>) {
    ^bb0(%in: f32, %out: f32):
      %50 = arith.addf %in, %out : f32
      linalg.yield %50 : f32
    } -> tensor<3x2xf32>
    %extracted_slice = tensor.extract_slice %arg1[1, 0] [1, 3] [1, 1] : tensor<2x3xi64> to tensor<1x3xi64>
    %collapsed = tensor.collapse_shape %extracted_slice [[0, 1]] : tensor<1x3xi64> into tensor<3xi64>
    %extracted_slice_9 = tensor.extract_slice %arg1[0, 0] [1, 3] [1, 1] : tensor<2x3xi64> to tensor<1x3xi64>
    %collapsed_10 = tensor.collapse_shape %extracted_slice_9 [[0, 1]] : tensor<1x3xi64> into tensor<3xi64>
    %11 = linalg.generic {indexing_maps = [#map3, #map4], iterator_types = ["parallel", "parallel"]} ins(%collapsed_10 : tensor<3xi64>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: i64, %out: f32):
      %50 = arith.index_cast %in : i64 to index
      %51 = linalg.index 1 : index
      %extracted = tensor.extract %8[%50, %51] : tensor<3x2xf32>
      linalg.yield %extracted : f32
    } -> tensor<3x2xf32>
    %12 = linalg.generic {indexing_maps = [#map3, #map4], iterator_types = ["parallel", "parallel"]} ins(%collapsed : tensor<3xi64>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: i64, %out: f32):
      %50 = arith.index_cast %in : i64 to index
      %51 = linalg.index 1 : index
      %extracted = tensor.extract %10[%50, %51] : tensor<3x2xf32>
      linalg.yield %extracted : f32
    } -> tensor<3x2xf32>
    %13 = linalg.generic {indexing_maps = [#map4, #map4, #map4], iterator_types = ["parallel", "parallel"]} ins(%11, %12 : tensor<3x2xf32>, tensor<3x2xf32>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: f32, %in_19: f32, %out: f32):
      %50 = arith.addf %in, %in_19 : f32
      linalg.yield %50 : f32
    } -> tensor<3x2xf32>
    %14 = linalg.generic {indexing_maps = [#map5, #map4, #map4], iterator_types = ["parallel", "parallel"]} ins(%cst_8, %13 : tensor<f32>, tensor<3x2xf32>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: f32, %in_19: f32, %out: f32):
      %50 = arith.cmpf ogt, %in, %in_19 : f32
      %51 = arith.select %50, %in, %in_19 : f32
      linalg.yield %51 : f32
    } -> tensor<3x2xf32>
    %15 = linalg.generic {indexing_maps = [#map5, #map4, #map4], iterator_types = ["parallel", "parallel"]} ins(%cst_8, %13 : tensor<f32>, tensor<3x2xf32>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: f32, %in_19: f32, %out: f32):
      %50 = arith.cmpf olt, %in, %in_19 : f32
      %51 = arith.select %50, %in, %in_19 : f32
      linalg.yield %51 : f32
    } -> tensor<3x2xf32>
    %16 = linalg.generic {indexing_maps = [#map4, #map4], iterator_types = ["parallel", "parallel"]} ins(%15 : tensor<3x2xf32>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: f32, %out: f32):
      %50 = arith.truncf %cst_6 : f64 to f32
      %51 = arith.mulf %in, %50 : f32
      linalg.yield %51 : f32
    } -> tensor<3x2xf32>
    %17 = linalg.generic {indexing_maps = [#map4, #map4, #map4], iterator_types = ["parallel", "parallel"]} ins(%14, %16 : tensor<3x2xf32>, tensor<3x2xf32>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: f32, %in_19: f32, %out: f32):
      %50 = arith.addf %in, %in_19 : f32
      linalg.yield %50 : f32
    } -> tensor<3x2xf32>
    %18 = tensor.empty() : tensor<3x2xi64>
    %19 = linalg.generic {indexing_maps = [#map3, #map4], iterator_types = ["parallel", "parallel"]} ins(%collapsed : tensor<3xi64>) outs(%18 : tensor<3x2xi64>) {
    ^bb0(%in: i64, %out: i64):
      linalg.yield %in : i64
    } -> tensor<3x2xi64>
    %20 = tensor.empty() : tensor<6x1xi64>
    %21 = linalg.fill ins(%c0_i64 : i64) outs(%20 : tensor<6x1xi64>) -> tensor<6x1xi64>
    %22 = tensor.empty() : tensor<6xf32>
    %23 = linalg.fill ins(%cst_0 : f32) outs(%22 : tensor<6xf32>) -> tensor<6xf32>
    %24:3 = linalg.generic {indexing_maps = [#map6, #map6, #map7], iterator_types = ["parallel"]} outs(%21, %21, %23 : tensor<6x1xi64>, tensor<6x1xi64>, tensor<6xf32>) {
    ^bb0(%out: i64, %out_19: i64, %out_20: f32):
      %50 = linalg.index 0 : index
      %51 = arith.remsi %50, %c2 : index
      %52 = arith.divsi %50, %c2 : index
      %53 = arith.remsi %52, %c3 : index
      %extracted = tensor.extract %19[%53, %51] : tensor<3x2xi64>
      %extracted_21 = tensor.extract %17[%53, %51] : tensor<3x2xf32>
      %54 = arith.index_cast %51 : index to i64
      linalg.yield %extracted, %54, %extracted_21 : i64, i64, f32
    } -> (tensor<6x1xi64>, tensor<6x1xi64>, tensor<6xf32>)
    %25 = tensor.empty() : tensor<6x2xi64>
    %26 = linalg.fill ins(%c0_i64 : i64) outs(%25 : tensor<6x2xi64>) -> tensor<6x2xi64>
    %inserted_slice = tensor.insert_slice %24#0 into %26[0, 0] [6, 1] [1, 1] : tensor<6x1xi64> into tensor<6x2xi64>
    %inserted_slice_11 = tensor.insert_slice %24#1 into %inserted_slice[0, 1] [6, 1] [1, 1] : tensor<6x1xi64> into tensor<6x2xi64>
    %27 = linalg.fill ins(%cst : f32) outs(%22 : tensor<6xf32>) -> tensor<6xf32>
    %28 = tm_tensor.scatter {dimension_map = array<i64: 0, 1>} unique_indices(false) ins(%27, %inserted_slice_11 : tensor<6xf32>, tensor<6x2xi64>) outs(%cst_2 : tensor<3x2xf32>) {
    ^bb0(%arg2: f32, %arg3: f32):
      tm_tensor.yield %arg2 : f32
    } -> tensor<3x2xf32>
    %29 = tm_tensor.scatter {dimension_map = array<i64: 0, 1>} unique_indices(false) ins(%24#2, %inserted_slice_11 : tensor<6xf32>, tensor<6x2xi64>) outs(%28 : tensor<3x2xf32>) {
    ^bb0(%arg2: f32, %arg3: f32):
      %50 = arith.maximumf %arg2, %arg3 : f32
      tm_tensor.yield %50 : f32
    } -> tensor<3x2xf32>
    %30 = linalg.generic {indexing_maps = [#map3, #map4], iterator_types = ["parallel", "parallel"]} ins(%collapsed : tensor<3xi64>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: i64, %out: f32):
      %50 = arith.index_cast %in : i64 to index
      %51 = linalg.index 1 : index
      %extracted = tensor.extract %29[%50, %51] : tensor<3x2xf32>
      linalg.yield %extracted : f32
    } -> tensor<3x2xf32>
    %31 = linalg.generic {indexing_maps = [#map4, #map4, #map4], iterator_types = ["parallel", "parallel"]} ins(%17, %30 : tensor<3x2xf32>, tensor<3x2xf32>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: f32, %in_19: f32, %out: f32):
      %50 = arith.subf %in, %in_19 : f32
      linalg.yield %50 : f32
    } -> tensor<3x2xf32>
    %32 = linalg.generic {indexing_maps = [#map4, #map4], iterator_types = ["parallel", "parallel"]} ins(%31 : tensor<3x2xf32>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: f32, %out: f32):
      %50 = math.exp %in : f32
      linalg.yield %50 : f32
    } -> tensor<3x2xf32>
    %33:3 = linalg.generic {indexing_maps = [#map6, #map6, #map7], iterator_types = ["parallel"]} outs(%21, %21, %23 : tensor<6x1xi64>, tensor<6x1xi64>, tensor<6xf32>) {
    ^bb0(%out: i64, %out_19: i64, %out_20: f32):
      %50 = linalg.index 0 : index
      %51 = arith.remsi %50, %c2 : index
      %52 = arith.divsi %50, %c2 : index
      %53 = arith.remsi %52, %c3 : index
      %extracted = tensor.extract %19[%53, %51] : tensor<3x2xi64>
      %extracted_21 = tensor.extract %32[%53, %51] : tensor<3x2xf32>
      %54 = arith.index_cast %51 : index to i64
      linalg.yield %extracted, %54, %extracted_21 : i64, i64, f32
    } -> (tensor<6x1xi64>, tensor<6x1xi64>, tensor<6xf32>)
    %inserted_slice_12 = tensor.insert_slice %33#0 into %26[0, 0] [6, 1] [1, 1] : tensor<6x1xi64> into tensor<6x2xi64>
    %inserted_slice_13 = tensor.insert_slice %33#1 into %inserted_slice_12[0, 1] [6, 1] [1, 1] : tensor<6x1xi64> into tensor<6x2xi64>
    %34 = tm_tensor.scatter {dimension_map = array<i64: 0, 1>} unique_indices(false) ins(%33#2, %inserted_slice_13 : tensor<6xf32>, tensor<6x2xi64>) outs(%cst_2 : tensor<3x2xf32>) {
    ^bb0(%arg2: f32, %arg3: f32):
      %50 = arith.addf %arg3, %arg2 : f32
      tm_tensor.yield %50 : f32
    } -> tensor<3x2xf32>
    %35 = linalg.generic {indexing_maps = [#map4, #map4], iterator_types = ["parallel", "parallel"]} ins(%34 : tensor<3x2xf32>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: f32, %out: f32):
      %50 = arith.truncf %cst_7 : f64 to f32
      %51 = arith.addf %in, %50 : f32
      linalg.yield %51 : f32
    } -> tensor<3x2xf32>
    %36 = linalg.generic {indexing_maps = [#map3, #map4], iterator_types = ["parallel", "parallel"]} ins(%collapsed : tensor<3xi64>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: i64, %out: f32):
      %50 = arith.index_cast %in : i64 to index
      %51 = linalg.index 1 : index
      %extracted = tensor.extract %35[%50, %51] : tensor<3x2xf32>
      linalg.yield %extracted : f32
    } -> tensor<3x2xf32>
    %37 = linalg.generic {indexing_maps = [#map4, #map4, #map4], iterator_types = ["parallel", "parallel"]} ins(%32, %36 : tensor<3x2xf32>, tensor<3x2xf32>) outs(%6 : tensor<3x2xf32>) {
    ^bb0(%in: f32, %in_19: f32, %out: f32):
      %50 = arith.divf %in, %in_19 : f32
      linalg.yield %50 : f32
    } -> tensor<3x2xf32>
    %38 = linalg.generic {indexing_maps = [#map8, #map], iterator_types = ["parallel", "parallel", "parallel"]} ins(%collapsed_10 : tensor<3xi64>) outs(%4 : tensor<3x2x2xf32>) {
    ^bb0(%in: i64, %out: f32):
      %50 = arith.index_cast %in : i64 to index
      %51 = linalg.index 1 : index
      %52 = linalg.index 2 : index
      %extracted = tensor.extract %expanded[%50, %51, %52] : tensor<3x2x2xf32>
      linalg.yield %extracted : f32
    } -> tensor<3x2x2xf32>
    %expanded_14 = tensor.expand_shape %37 [[0], [1, 2]] output_shape [3, 2, 1] : tensor<3x2xf32> into tensor<3x2x1xf32>
    %39 = linalg.generic {indexing_maps = [#map9, #map, #map], iterator_types = ["parallel", "parallel", "parallel"]} ins(%expanded_14, %38 : tensor<3x2x1xf32>, tensor<3x2x2xf32>) outs(%4 : tensor<3x2x2xf32>) {
    ^bb0(%in: f32, %in_19: f32, %out: f32):
      %50 = arith.mulf %in, %in_19 : f32
      linalg.yield %50 : f32
    } -> tensor<3x2x2xf32>
    %40 = tensor.empty() : tensor<3x2x2xi64>
    %41 = linalg.generic {indexing_maps = [#map8, #map], iterator_types = ["parallel", "parallel", "parallel"]} ins(%collapsed : tensor<3xi64>) outs(%40 : tensor<3x2x2xi64>) {
    ^bb0(%in: i64, %out: i64):
      linalg.yield %in : i64
    } -> tensor<3x2x2xi64>
    %42 = tensor.empty() : tensor<12x1xi64>
    %43 = linalg.fill ins(%c0_i64 : i64) outs(%42 : tensor<12x1xi64>) -> tensor<12x1xi64>
    %44 = tensor.empty() : tensor<12xf32>
    %45 = linalg.fill ins(%cst_0 : f32) outs(%44 : tensor<12xf32>) -> tensor<12xf32>
    %46:4 = linalg.generic {indexing_maps = [#map6, #map6, #map6, #map7], iterator_types = ["parallel"]} outs(%43, %43, %43, %45 : tensor<12x1xi64>, tensor<12x1xi64>, tensor<12x1xi64>, tensor<12xf32>) {
    ^bb0(%out: i64, %out_19: i64, %out_20: i64, %out_21: f32):
      %50 = linalg.index 0 : index
      %51 = arith.remsi %50, %c2 : index
      %52 = arith.divsi %50, %c2 : index
      %53 = arith.remsi %52, %c2 : index
      %54 = arith.divsi %52, %c2 : index
      %55 = arith.remsi %54, %c3 : index
      %extracted = tensor.extract %41[%55, %53, %51] : tensor<3x2x2xi64>
      %extracted_22 = tensor.extract %39[%55, %53, %51] : tensor<3x2x2xf32>
      %56 = arith.index_cast %53 : index to i64
      %57 = arith.index_cast %51 : index to i64
      linalg.yield %extracted, %56, %57, %extracted_22 : i64, i64, i64, f32
    } -> (tensor<12x1xi64>, tensor<12x1xi64>, tensor<12x1xi64>, tensor<12xf32>)
    %47 = tensor.empty() : tensor<12x3xi64>
    %48 = linalg.fill ins(%c0_i64 : i64) outs(%47 : tensor<12x3xi64>) -> tensor<12x3xi64>
    %inserted_slice_15 = tensor.insert_slice %46#0 into %48[0, 0] [12, 1] [1, 1] : tensor<12x1xi64> into tensor<12x3xi64>
    %inserted_slice_16 = tensor.insert_slice %46#1 into %inserted_slice_15[0, 1] [12, 1] [1, 1] : tensor<12x1xi64> into tensor<12x3xi64>
    %inserted_slice_17 = tensor.insert_slice %46#2 into %inserted_slice_16[0, 2] [12, 1] [1, 1] : tensor<12x1xi64> into tensor<12x3xi64>
    %49 = tm_tensor.scatter {dimension_map = array<i64: 0, 1, 2>} unique_indices(false) ins(%46#3, %inserted_slice_17 : tensor<12xf32>, tensor<12x3xi64>) outs(%cst_1 : tensor<3x2x2xf32>) {
    ^bb0(%arg2: f32, %arg3: f32):
      %50 = arith.addf %arg3, %arg2 : f32
      tm_tensor.yield %50 : f32
    } -> tensor<3x2x2xf32>
    %collapsed_18 = tensor.collapse_shape %49 [[0], [1, 2]] : tensor<3x2x2xf32> into tensor<3x4xf32>
    return %collapsed_18 : tensor<3x4xf32>
  }
}

{-#
  dialect_resources: {
    builtin: {
      torch_tensor_4_4_torch.float32: "0x040000002A4BAF3ECC06053F1E4D16BF1E16C1BE630DA13E5E19383F728136BE10E7253F63F00EBE8BACBB3D10BF483FB6AA4DBFF4910BBF6D8260BED9D6ACBE178D3F3F",
      torch_tensor_1_2_2_torch.float32: "0x04000000103A4BBF905410BF4C0C5BBF7BD292BF",
      torch_tensor_1_2_2_torch.float32_1: "0x04000000DC0537BFC5C1863FAAE70B3F2FF6173F"
    }
  }
#-}

