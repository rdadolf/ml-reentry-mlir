// Test 7: COO at the boundary → CSR for computation.
//
// Models the EdgeIndex-style ingress pattern: the user hands us a COO
// sparse adjacency, but inside the kernel we convert it to CSR before
// running computation that benefits from CSR codegen (e.g., GPU
// codegen with parallelization-strategy=dense-outer-loop, which COO's
// non-dense outer dim cannot satisfy).
//
// Pipeline path: input COO → sparse_tensor.convert → CSR → linalg.matmul
// → dense output.

#COO = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d0 : compressed(nonunique), d1 : singleton),
  posWidth = 32, crdWidth = 32
}>

#CSR = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d0 : dense, d1 : compressed),
  posWidth = 32, crdWidth = 32
}>

module {
  func.func private @printMemrefF32(memref<*xf32>)

  func.func @spmm_from_coo(%A_coo: tensor<8x8xf32, #COO>,
                           %B: tensor<8x8xf32>,
                           %C: tensor<8x8xf32>) -> tensor<8x8xf32> {
    // The conversion that EdgeIndex's lazy rowptr-cache amortizes.
    %A_csr = sparse_tensor.convert %A_coo
      : tensor<8x8xf32, #COO> to tensor<8x8xf32, #CSR>
    %D = linalg.matmul
      ins(%A_csr, %B : tensor<8x8xf32, #CSR>, tensor<8x8xf32>)
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

    %A_coo = sparse_tensor.convert %dense_A : tensor<8x8xf32> to tensor<8x8xf32, #COO>

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

    %D = call @spmm_from_coo(%A_coo, %B, %C)
      : (tensor<8x8xf32, #COO>, tensor<8x8xf32>, tensor<8x8xf32>) -> tensor<8x8xf32>

    %D_buf = bufferization.to_buffer %D : tensor<8x8xf32> to memref<8x8xf32>
    %D_cast = memref.cast %D_buf : memref<8x8xf32> to memref<*xf32>
    call @printMemrefF32(%D_cast) : (memref<*xf32>) -> ()

    bufferization.dealloc_tensor %A_coo : tensor<8x8xf32, #COO>
    return
  }
}
