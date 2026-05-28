// Test 6: SpMM with COO encoding via GPU codegen.
//
// Same kernel as 01-spmm-coo.mlir, but driven through the GPU codegen
// pipeline that was validated for CSR in experiments/gpu-sparsifier.
//
// The CSR baseline relied on `parallelization-strategy=dense-outer-loop`,
// which requires the outer dim to be `dense`. COO's outer dim is
// `compressed(nonunique)`. Expected outcome: codegen falls through to
// runtime-library (or fails); the parallel-loop rewriter has nothing
// to grab onto.

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

    %C_e = tensor.empty() : tensor<8x8xf32>
    %C = linalg.fill ins(%f0 : f32) outs(%C_e : tensor<8x8xf32>) -> tensor<8x8xf32>

    %D = call @spmm(%A, %B, %C) : (tensor<8x8xf32, #COO>, tensor<8x8xf32>, tensor<8x8xf32>) -> tensor<8x8xf32>

    %D_buf = bufferization.to_buffer %D : tensor<8x8xf32> to memref<8x8xf32>
    %D_cast = memref.cast %D_buf : memref<8x8xf32> to memref<*xf32>
    call @printMemrefF32(%D_cast) : (memref<*xf32>) -> ()

    bufferization.dealloc_tensor %A : tensor<8x8xf32, #COO>
    return
  }
}
