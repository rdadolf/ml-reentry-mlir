// Test 4, COO variant: per-row sum reduction.
// Identical to 04-segreduce-csr.mlir except the encoding.

#COO = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d0 : compressed(nonunique), d1 : singleton),
  posWidth = 32,
  crdWidth = 32
}>

#trait_segsum = {
  indexing_maps = [
    affine_map<(i,j) -> (i,j)>,
    affine_map<(i,j) -> (j)>,
    affine_map<(i,j) -> (i)>
  ],
  iterator_types = ["parallel", "reduction"]
}

module {
  func.func private @printMemrefF32(memref<*xf32>)

  func.func @sum_per_row(%a: tensor<8x8xf32, #COO>,
                         %ones: tensor<8xf32>,
                         %init: tensor<8xf32>) -> tensor<8xf32> {
    %r = linalg.generic #trait_segsum
      ins(%a, %ones : tensor<8x8xf32, #COO>, tensor<8xf32>)
      outs(%init : tensor<8xf32>) {
    ^bb(%av: f32, %ov: f32, %x: f32):
      %m = arith.mulf %av, %ov : f32
      %s = arith.addf %x, %m : f32
      linalg.yield %s : f32
    } -> tensor<8xf32>
    return %r : tensor<8xf32>
  }

  func.func @main() {
    %f0 = arith.constant 0.0 : f32
    %f1 = arith.constant 1.0 : f32

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

    %a = sparse_tensor.convert %dense : tensor<8x8xf32> to tensor<8x8xf32, #COO>

    %ones_e = tensor.empty() : tensor<8xf32>
    %ones = linalg.fill ins(%f1 : f32) outs(%ones_e : tensor<8xf32>) -> tensor<8xf32>

    %init_e = tensor.empty() : tensor<8xf32>
    %init = linalg.fill ins(%f0 : f32) outs(%init_e : tensor<8xf32>) -> tensor<8xf32>

    %sum = call @sum_per_row(%a, %ones, %init)
      : (tensor<8x8xf32, #COO>, tensor<8xf32>, tensor<8xf32>) -> tensor<8xf32>

    %sum_buf = bufferization.to_buffer %sum : tensor<8xf32> to memref<8xf32>
    %sum_cast = memref.cast %sum_buf : memref<8xf32> to memref<*xf32>
    call @printMemrefF32(%sum_cast) : (memref<*xf32>) -> ()

    bufferization.dealloc_tensor %a : tensor<8x8xf32, #COO>
    return
  }
}
