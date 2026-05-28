// Test 3, COO variant: sparse + sparse → sparse binary.
// Identical to 03-binary-csr.mlir except the encoding.

#COO = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d0 : compressed(nonunique), d1 : singleton),
  posWidth = 32,
  crdWidth = 32
}>

#trait_add = {
  indexing_maps = [
    affine_map<(i,j) -> (i,j)>,
    affine_map<(i,j) -> (i,j)>,
    affine_map<(i,j) -> (i,j)>
  ],
  iterator_types = ["parallel", "parallel"]
}

module {
  func.func @binary_add(%arga: tensor<8x8xf32, #COO>,
                        %argb: tensor<8x8xf32, #COO>) -> tensor<8x8xf32, #COO> {
    %init = tensor.empty() : tensor<8x8xf32, #COO>
    %r = linalg.generic #trait_add
      ins(%arga, %argb : tensor<8x8xf32, #COO>, tensor<8x8xf32, #COO>)
      outs(%init : tensor<8x8xf32, #COO>) {
    ^bb(%a: f32, %b: f32, %x: f32):
      %sum = arith.addf %a, %b : f32
      linalg.yield %sum : f32
    } -> tensor<8x8xf32, #COO>
    return %r : tensor<8x8xf32, #COO>
  }

  func.func @main() {
    %f0 = arith.constant 0.0 : f32

    %dense_a = tensor.generate {
    ^bb0(%i: index, %j: index):
      %s = arith.addi %i, %j : index
      %c3 = arith.constant 3 : index
      %m = arith.remui %s, %c3 : index
      %c0_ix = arith.constant 0 : index
      %is_nz = arith.cmpi eq, %m, %c0_ix : index
      %c1_ix = arith.constant 1 : index
      %iv = arith.addi %i, %c1_ix : index
      %iv_i64 = arith.index_cast %iv : index to i64
      %iv_f = arith.uitofp %iv_i64 : i64 to f32
      %c10 = arith.constant 10.0 : f32
      %v = arith.mulf %iv_f, %c10 : f32
      %final = arith.select %is_nz, %v, %f0 : f32
      tensor.yield %final : f32
    } : tensor<8x8xf32>

    %dense_b = tensor.generate {
    ^bb0(%i: index, %j: index):
      %c2 = arith.constant 2 : index
      %tj = arith.muli %c2, %j : index
      %s = arith.addi %i, %tj : index
      %c3 = arith.constant 3 : index
      %m = arith.remui %s, %c3 : index
      %c0_ix = arith.constant 0 : index
      %is_nz = arith.cmpi eq, %m, %c0_ix : index
      %j_i64 = arith.index_cast %j : index to i64
      %j_f = arith.uitofp %j_i64 : i64 to f32
      %c100 = arith.constant 100.0 : f32
      %v = arith.mulf %j_f, %c100 : f32
      %final = arith.select %is_nz, %v, %f0 : f32
      tensor.yield %final : f32
    } : tensor<8x8xf32>

    %a = sparse_tensor.convert %dense_a : tensor<8x8xf32> to tensor<8x8xf32, #COO>
    %b = sparse_tensor.convert %dense_b : tensor<8x8xf32> to tensor<8x8xf32, #COO>
    %r = call @binary_add(%a, %b)
      : (tensor<8x8xf32, #COO>, tensor<8x8xf32, #COO>) -> tensor<8x8xf32, #COO>
    sparse_tensor.print %r : tensor<8x8xf32, #COO>
    bufferization.dealloc_tensor %a : tensor<8x8xf32, #COO>
    bufferization.dealloc_tensor %b : tensor<8x8xf32, #COO>
    bufferization.dealloc_tensor %r : tensor<8x8xf32, #COO>
    return
  }
}
