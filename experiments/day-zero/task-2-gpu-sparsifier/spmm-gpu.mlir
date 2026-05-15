// GPU variant for Day-0 Task 2.
//
// Same kernel as spmm-cpu.mlir, but the driver brackets execution with
// `mgpuCreateSparseEnv` / `mgpuDestroySparseEnv` as the upstream
// sparse-matmul-lib.mlir integration test does. These symbols come from a
// CUDA-cuSPARSE-aware MLIR runtime build (`MLIR_ENABLE_CUDA_CUSPARSE=ON`);
// stock `MLIR_ENABLE_CUDA_RUNNER=ON` is not enough.
//
// The kernel is identical to the CPU baseline (same linalg.matmul on a CSR
// operand). What differs is the sparsifier invocation (--enable-gpu-libgen
// or --gpu-num-threads=N), driven by run.sh.

#CSR = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d0 : dense, d1 : compressed),
  posWidth = 32,
  crdWidth = 32
}>

module {
  llvm.func @mgpuCreateSparseEnv()
  llvm.func @mgpuDestroySparseEnv()
  func.func private @printMemrefF32(memref<*xf32>)

  func.func @spmm(%A: tensor<8x8xf32, #CSR>,
                  %B: tensor<8x8xf32>,
                  %C: tensor<8x8xf32>) -> tensor<8x8xf32> {
    %D = linalg.matmul
      ins(%A, %B : tensor<8x8xf32, #CSR>, tensor<8x8xf32>)
      outs(%C : tensor<8x8xf32>) -> tensor<8x8xf32>
    return %D : tensor<8x8xf32>
  }

  func.func @main() {
    llvm.call @mgpuCreateSparseEnv() : () -> ()

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

    %A = sparse_tensor.convert %dense_A : tensor<8x8xf32> to tensor<8x8xf32, #CSR>

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

    %D = call @spmm(%A, %B, %C) : (tensor<8x8xf32, #CSR>,
                                   tensor<8x8xf32>,
                                   tensor<8x8xf32>) -> tensor<8x8xf32>

    %D_buf = bufferization.to_buffer %D : tensor<8x8xf32> to memref<8x8xf32>
    %D_cast = memref.cast %D_buf : memref<8x8xf32> to memref<*xf32>
    call @printMemrefF32(%D_cast) : (memref<*xf32>) -> ()

    bufferization.dealloc_tensor %A : tensor<8x8xf32, #CSR>
    llvm.call @mgpuDestroySparseEnv() : () -> ()
    return
  }
}
