// Test 5, COO variant. Identical to 05-spmm-weighted-csr.mlir except encoding.

#COO = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d0 : compressed(nonunique), d1 : singleton),
  posWidth = 32,
  crdWidth = 32
}>

module {
  func.func private @printMemrefF32(memref<*xf32>)

  func.func @weighted_spmm(%a: tensor<8x8xf32, #COO>,
                           %x: tensor<8x4xf32>,
                           %y: tensor<8x4xf32>) -> tensor<8x4xf32> {
    %r = linalg.matmul
      ins(%a, %x : tensor<8x8xf32, #COO>, tensor<8x4xf32>)
      outs(%y : tensor<8x4xf32>) -> tensor<8x4xf32>
    return %r : tensor<8x4xf32>
  }

  func.func @main() {
    %f0 = arith.constant 0.0 : f32

    %dense_a = tensor.generate {
    ^bb0(%i: index, %j: index):
      %s = arith.addi %i, %j : index
      %s_i64 = arith.index_cast %s : index to i64
      %s_f = arith.uitofp %s_i64 : i64 to f32
      %c3 = arith.constant 3 : index
      %m = arith.remui %s, %c3 : index
      %c0_ix = arith.constant 0 : index
      %is_zero = arith.cmpi eq, %m, %c0_ix : index
      %half = arith.constant 0.5 : f32
      %v = arith.mulf %s_f, %half : f32
      %final = arith.select %is_zero, %v, %f0 : f32
      tensor.yield %final : f32
    } : tensor<8x8xf32>

    %a = sparse_tensor.convert %dense_a : tensor<8x8xf32> to tensor<8x8xf32, #COO>

    %x = tensor.generate {
    ^bb0(%j: index, %k: index):
      %c10 = arith.constant 10 : index
      %t = arith.muli %j, %c10 : index
      %s = arith.addi %t, %k : index
      %s_i64 = arith.index_cast %s : index to i64
      %s_f = arith.uitofp %s_i64 : i64 to f32
      tensor.yield %s_f : f32
    } : tensor<8x4xf32>

    %y_e = tensor.empty() : tensor<8x4xf32>
    %y = linalg.fill ins(%f0 : f32) outs(%y_e : tensor<8x4xf32>) -> tensor<8x4xf32>

    %r = call @weighted_spmm(%a, %x, %y)
      : (tensor<8x8xf32, #COO>, tensor<8x4xf32>, tensor<8x4xf32>) -> tensor<8x4xf32>

    %r_buf = bufferization.to_buffer %r : tensor<8x4xf32> to memref<8x4xf32>
    %r_cast = memref.cast %r_buf : memref<8x4xf32> to memref<*xf32>
    call @printMemrefF32(%r_cast) : (memref<*xf32>) -> ()

    bufferization.dealloc_tensor %a : tensor<8x8xf32, #COO>
    return
  }
}
