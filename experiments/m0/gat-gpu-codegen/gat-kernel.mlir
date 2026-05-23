// GAT-shaped fused-loop probe kernel, hand-written.
//
// Three stages, expressed as three linalg.generic blocks over a shared CSR
// adjacency operand α[N,N]:
//
//   1. m[i] = max_j α[i,j]                                    (row-wise max)
//   2. s[i] = Σ_j exp(α[i,j] - m[i])                          (row-wise expsum)
//   3. Y[i,k] = Σ_j (exp(α[i,j] - m[i]) / s[i]) · X[j,k]      (weighted SpMM)
//
// Same kernel runs through both the CPU sparsifier pipeline and the
// gpu-codegen pipeline; the driver (run.py) just varies the --sparsifier
// flags. Output Y is printed via printMemrefF32; CPU and GPU outputs are
// numerically compared (reductions + transcendentals aren't bit-stable
// across CPU/GPU).

#CSR = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d0 : dense, d1 : compressed),
  posWidth = 64,
  crdWidth = 64
}>

module {
  func.func private @printMemrefF32(memref<*xf32>)

  // Stage 1: row-wise max over the stored values of α.
  //
  // Uses sparse_tensor.reduce because the reduction is over present edges
  // only — the implicit "max with 0" semantics of a bare arith.maximumf
  // over a sparse operand would be wrong for GAT (an absent edge mustn't
  // contribute a zero to the row max). Identity = -inf.
  func.func @row_max(%alpha: tensor<64x64xf32, #CSR>) -> tensor<64xf32> {
    %neg_inf = arith.constant 0xFF800000 : f32
    %m_init = tensor.generate {
    ^bb0(%i: index):
      tensor.yield %neg_inf : f32
    } : tensor<64xf32>
    %m = linalg.generic {
      indexing_maps = [
        affine_map<(d0, d1) -> (d0, d1)>,
        affine_map<(d0, d1) -> (d0)>
      ],
      iterator_types = ["parallel", "reduction"]
    } ins(%alpha : tensor<64x64xf32, #CSR>)
      outs(%m_init : tensor<64xf32>) {
    ^bb0(%a: f32, %out: f32):
      %r = sparse_tensor.reduce %a, %out, %neg_inf : f32 {
        ^bb0(%x: f32, %y: f32):
          %mx = arith.maximumf %x, %y : f32
          sparse_tensor.yield %mx : f32
      }
      linalg.yield %r : f32
    } -> tensor<64xf32>
    return %m : tensor<64xf32>
  }

  // Stage 2: row-wise sum of exp(α[i,j] - m[i]).
  func.func @row_expsum(%alpha: tensor<64x64xf32, #CSR>,
                        %m: tensor<64xf32>) -> tensor<64xf32> {
    %zero = arith.constant 0.0 : f32
    %s_init = tensor.generate {
    ^bb0(%i: index):
      tensor.yield %zero : f32
    } : tensor<64xf32>
    // Reduce over stored edges only: GAT's softmax normalizes over a
    // node's actual neighbors, not over the full N×N (i,j) lattice. The
    // body — exp(α[i,j] - m[i]) — is meaningful only at present edges;
    // its value at an absent edge would be exp(-m[i]), which has no
    // place in the GAT math. sparse_tensor.reduce expresses "iterate
    // only over present values" with identity = 0 for the sum.
    %s = linalg.generic {
      indexing_maps = [
        affine_map<(d0, d1) -> (d0, d1)>,
        affine_map<(d0, d1) -> (d0)>,
        affine_map<(d0, d1) -> (d0)>
      ],
      iterator_types = ["parallel", "reduction"]
    } ins(%alpha, %m : tensor<64x64xf32, #CSR>, tensor<64xf32>)
      outs(%s_init : tensor<64xf32>) {
    ^bb0(%a: f32, %m_val: f32, %out: f32):
      %r = sparse_tensor.reduce %a, %out, %zero : f32 {
        ^bb0(%x: f32, %y: f32):
          %diff = arith.subf %x, %m_val : f32
          %ex = math.exp %diff : f32
          %sum = arith.addf %y, %ex : f32
          sparse_tensor.yield %sum : f32
      }
      linalg.yield %r : f32
    } -> tensor<64xf32>
    return %s : tensor<64xf32>
  }

  // Stage 3: Y[i,k] = Σ_j (exp(α[i,j] - m[i]) / s[i]) · X[j,k].
  // The SpMM-shape iteration over j is sparse (only nonzero α entries);
  // k is dense (the feature axis); i is the outer parallel axis (rows).
  func.func @weighted_aggregate(%alpha: tensor<64x64xf32, #CSR>,
                                %m: tensor<64xf32>,
                                %s: tensor<64xf32>,
                                %X: tensor<64x32xf32>) -> tensor<64x32xf32> {
    %zero = arith.constant 0.0 : f32
    %Y_init = tensor.generate {
    ^bb0(%i: index, %k: index):
      tensor.yield %zero : f32
    } : tensor<64x32xf32>
    // Reduce over stored edges only, same as stage 2. The attention-
    // weighted contribution (exp(α - m) / s) · X[j,k] is meaningful only
    // at present edges. Identity = 0 for the sum.
    %Y = linalg.generic {
      indexing_maps = [
        affine_map<(d0, d1, d2) -> (d0, d1)>,    // alpha[i,j]
        affine_map<(d0, d1, d2) -> (d0)>,        // m[i]
        affine_map<(d0, d1, d2) -> (d0)>,        // s[i]
        affine_map<(d0, d1, d2) -> (d1, d2)>,    // X[j,k]
        affine_map<(d0, d1, d2) -> (d0, d2)>     // Y[i,k]
      ],
      iterator_types = ["parallel", "reduction", "parallel"]
    } ins(%alpha, %m, %s, %X
            : tensor<64x64xf32, #CSR>, tensor<64xf32>, tensor<64xf32>, tensor<64x32xf32>)
      outs(%Y_init : tensor<64x32xf32>) {
    ^bb0(%a: f32, %m_val: f32, %s_val: f32, %x: f32, %out: f32):
      %r = sparse_tensor.reduce %a, %out, %zero : f32 {
        ^bb0(%xa: f32, %y: f32):
          %diff = arith.subf %xa, %m_val : f32
          %ex = math.exp %diff : f32
          %weight = arith.divf %ex, %s_val : f32
          %prod = arith.mulf %weight, %x : f32
          %acc = arith.addf %y, %prod : f32
          sparse_tensor.yield %acc : f32
      }
      linalg.yield %r : f32
    } -> tensor<64x32xf32>
    return %Y : tensor<64x32xf32>
  }

  func.func @main() {
    // ---------- inputs ----------
    %f0 = arith.constant 0.0 : f32

    // Dense α[64,64]: nonzero where (i + j) mod 11 == 0 (~5.8 nonzeros/row).
    // Value: α[i,j] = ((i + 2j) mod 13 - 6) * 0.3, giving f32 values in
    // [-1.8, 1.8] across edges. Coprime moduli (11 for edge-pattern, 13 for
    // value) ensure values vary within each row and the max isn't trivially
    // the only positive value — exercises arith.maximumf semantics over
    // present values.
    %dense_alpha = tensor.generate {
    ^bb0(%i: index, %j: index):
      %i_i64 = arith.index_cast %i : index to i64
      %j_i64 = arith.index_cast %j : index to i64
      %sum_ij = arith.addi %i_i64, %j_i64 : i64
      %c11 = arith.constant 11 : i64
      %mod11 = arith.remsi %sum_ij, %c11 : i64
      %c0_i64 = arith.constant 0 : i64
      %is_edge = arith.cmpi eq, %mod11, %c0_i64 : i64

      %c2 = arith.constant 2 : i64
      %j2 = arith.muli %j_i64, %c2 : i64
      %i_plus_2j = arith.addi %i_i64, %j2 : i64
      %c13 = arith.constant 13 : i64
      %val_mod13 = arith.remsi %i_plus_2j, %c13 : i64
      %c6 = arith.constant 6 : i64
      %centered = arith.subi %val_mod13, %c6 : i64
      %centered_f = arith.sitofp %centered : i64 to f32
      %scale = arith.constant 0.3 : f32
      %alpha_val = arith.mulf %centered_f, %scale : f32

      %v = arith.select %is_edge, %alpha_val, %f0 : f32
      tensor.yield %v : f32
    } : tensor<64x64xf32>

    %alpha = sparse_tensor.convert %dense_alpha
        : tensor<64x64xf32> to tensor<64x64xf32, #CSR>

    // Dense X[64,32]: X[j,k] = j * 0.01 + k * 0.001. Small magnitudes.
    %X = tensor.generate {
    ^bb0(%j: index, %k: index):
      %j_i64 = arith.index_cast %j : index to i64
      %k_i64 = arith.index_cast %k : index to i64
      %j_f = arith.sitofp %j_i64 : i64 to f32
      %k_f = arith.sitofp %k_i64 : i64 to f32
      %c01 = arith.constant 0.01 : f32
      %c001 = arith.constant 0.001 : f32
      %jc = arith.mulf %j_f, %c01 : f32
      %kc = arith.mulf %k_f, %c001 : f32
      %v = arith.addf %jc, %kc : f32
      tensor.yield %v : f32
    } : tensor<64x32xf32>

    // ---------- compute ----------
    %m = call @row_max(%alpha) : (tensor<64x64xf32, #CSR>) -> tensor<64xf32>
    %s = call @row_expsum(%alpha, %m)
        : (tensor<64x64xf32, #CSR>, tensor<64xf32>) -> tensor<64xf32>
    %Y = call @weighted_aggregate(%alpha, %m, %s, %X)
        : (tensor<64x64xf32, #CSR>, tensor<64xf32>, tensor<64xf32>, tensor<64x32xf32>)
          -> tensor<64x32xf32>

    // ---------- print Y ----------
    %Y_buf = bufferization.to_buffer %Y : tensor<64x32xf32> to memref<64x32xf32>
    %Y_cast = memref.cast %Y_buf : memref<64x32xf32> to memref<*xf32>
    call @printMemrefF32(%Y_cast) : (memref<*xf32>) -> ()

    bufferization.dealloc_tensor %alpha : tensor<64x64xf32, #CSR>
    return
  }
}
