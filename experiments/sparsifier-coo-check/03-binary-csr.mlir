// Test 3, baseline: sparse + sparse → sparse binary (CSR).
//
// output[i,j] = A[i,j] + B[i,j], with output sparsity = union of A and B.
// This exercises the merge-iteration over two sparse operands feeding a
// sparse output — closer to the GAT edge-mask shape (intersection of
// adjacency with attention-weights).
//
// Pattern adapted from upstream sparse_binary.mlir.

#CSR = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d0 : dense, d1 : compressed),
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
  func.func @binary_add(%arga: tensor<8x8xf32, #CSR>,
                        %argb: tensor<8x8xf32, #CSR>) -> tensor<8x8xf32, #CSR> {
    %init = tensor.empty() : tensor<8x8xf32, #CSR>
    %r = linalg.generic #trait_add
      ins(%arga, %argb : tensor<8x8xf32, #CSR>, tensor<8x8xf32, #CSR>)
      outs(%init : tensor<8x8xf32, #CSR>) {
    ^bb(%a: f32, %b: f32, %x: f32):
      %sum = arith.addf %a, %b : f32
      linalg.yield %sum : f32
    } -> tensor<8x8xf32, #CSR>
    return %r : tensor<8x8xf32, #CSR>
  }

  func.func @main() {
    %f0 = arith.constant 0.0 : f32

    // A: 1.0 at (i+j) % 3 == 0; values = (i+1)*10 when nonzero
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

    // B: 1.0 at (i+2*j) % 3 == 0; values = j*100 when nonzero
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

    %a = sparse_tensor.convert %dense_a : tensor<8x8xf32> to tensor<8x8xf32, #CSR>
    %b = sparse_tensor.convert %dense_b : tensor<8x8xf32> to tensor<8x8xf32, #CSR>
    %r = call @binary_add(%a, %b)
      : (tensor<8x8xf32, #CSR>, tensor<8x8xf32, #CSR>) -> tensor<8x8xf32, #CSR>
    sparse_tensor.print %r : tensor<8x8xf32, #CSR>
    bufferization.dealloc_tensor %a : tensor<8x8xf32, #CSR>
    bufferization.dealloc_tensor %b : tensor<8x8xf32, #CSR>
    bufferization.dealloc_tensor %r : tensor<8x8xf32, #CSR>
    return
  }
}
