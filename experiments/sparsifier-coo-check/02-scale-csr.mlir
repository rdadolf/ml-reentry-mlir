// Test 2, baseline: sparse-in-place scale (CSR).
//
// `output[i,j] = 2.0 * input[i,j]` over sparse input. Iteration is over
// input's nonzeros; output has the same sparsity pattern. This is the
// canonical "sparse → sparse same-pattern" idiom from upstream
// sparse_scale.mlir, and it's the pattern that DOES legalize cleanly
// (in contrast with the direct SDDMM attempt that failed; see
// 02-sddmm-attempt-csr.mlir below).

#CSR = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d0 : dense, d1 : compressed),
  posWidth = 32,
  crdWidth = 32
}>

#trait_scale = {
  indexing_maps = [
    affine_map<(i,j) -> (i,j)>
  ],
  iterator_types = ["parallel", "parallel"]
}

module {
  func.func @sparse_scale(%argx: tensor<8x8xf32, #CSR>) -> tensor<8x8xf32, #CSR> {
    %c = arith.constant 2.0 : f32
    %0 = linalg.generic #trait_scale
      outs(%argx: tensor<8x8xf32, #CSR>) {
        ^bb(%x: f32):
          %1 = arith.mulf %x, %c : f32
          linalg.yield %1 : f32
    } -> tensor<8x8xf32, #CSR>
    return %0 : tensor<8x8xf32, #CSR>
  }

  func.func @main() {
    %f0 = arith.constant 0.0 : f32

    // 8x8 with ~1/3 sparsity, values = i+j when nonzero.
    %dense = tensor.generate {
    ^bb0(%i: index, %j: index):
      %s = arith.addi %i, %j : index
      %s_i64 = arith.index_cast %s : index to i64
      %s_f = arith.uitofp %s_i64 : i64 to f32
      %c3 = arith.constant 3 : index
      %m = arith.remui %s, %c3 : index
      %c0_ix = arith.constant 0 : index
      %is_zero = arith.cmpi eq, %m, %c0_ix : index
      %v = arith.select %is_zero, %s_f, %f0 : f32
      tensor.yield %v : f32
    } : tensor<8x8xf32>

    %s = sparse_tensor.convert %dense : tensor<8x8xf32> to tensor<8x8xf32, #CSR>
    %r = call @sparse_scale(%s) : (tensor<8x8xf32, #CSR>) -> tensor<8x8xf32, #CSR>
    sparse_tensor.print %r : tensor<8x8xf32, #CSR>
    bufferization.dealloc_tensor %r : tensor<8x8xf32, #CSR>
    return
  }
}
