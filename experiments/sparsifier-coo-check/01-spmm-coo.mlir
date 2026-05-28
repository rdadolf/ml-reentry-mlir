// Test 1, COO variant: SpMM (C = A * B) with A in COO.
//
// Identical to 01-spmm-csr.mlir except the encoding on A. If the sparsifier
// is mature on the COO path, the output should be bit-identical to the CSR
// reference.
//
// COO is encoded as { compressed(nonunique), singleton } per the
// Chou-Kjolstad level-format theory. `compressed(nonunique)` on the outer
// dim allows duplicate row coordinates (EdgeIndex semantics — multigraphs
// permitted); `singleton` on the inner dim stores one coord per entry.

#COO = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d0 : compressed(nonunique), d1 : singleton),
  posWidth = 32,
  crdWidth = 32
}>

module {
  func.func private @printMemrefF32(memref<*xf32>)

  func.func @spmm(%A: tensor<8x8xf32, #COO>,
                  %B: tensor<8x8xf32>,
                  %C: tensor<8x8xf32>) -> tensor<8x8xf32> {
    %D = linalg.matmul
      ins(%A, %B : tensor<8x8xf32, #COO>, tensor<8x8xf32>)
      outs(%C : tensor<8x8xf32>) -> tensor<8x8xf32>
    return %D : tensor<8x8xf32>
  }

  func.func @main() {
    %f0 = arith.constant 0.0 : f32

    %dense_A = tensor.generate {
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

    %A = sparse_tensor.convert %dense_A : tensor<8x8xf32> to tensor<8x8xf32, #COO>

    %B = tensor.generate {
    ^bb0(%i: index, %j: index):
      %c8 = arith.constant 8 : index
      %r = arith.muli %i, %c8 : index
      %s = arith.addi %r, %j : index
      %s_i64 = arith.index_cast %s : index to i64
      %s_f = arith.uitofp %s_i64 : i64 to f32
      %hundredth = arith.constant 1.0e-2 : f32
      %v = arith.mulf %s_f, %hundredth : f32
      tensor.yield %v : f32
    } : tensor<8x8xf32>

    %C = tensor.generate {
    ^bb0(%i: index, %j: index):
      tensor.yield %f0 : f32
    } : tensor<8x8xf32>

    %D = call @spmm(%A, %B, %C) : (tensor<8x8xf32, #COO>,
                                   tensor<8x8xf32>,
                                   tensor<8x8xf32>) -> tensor<8x8xf32>

    %D_buf = bufferization.to_buffer %D : tensor<8x8xf32> to memref<8x8xf32>
    %D_cast = memref.cast %D_buf : memref<8x8xf32> to memref<*xf32>
    call @printMemrefF32(%D_cast) : (memref<*xf32>) -> ()

    bufferization.dealloc_tensor %A : tensor<8x8xf32, #COO>
    return
  }
}
