#!/usr/bin/env bash
# Drive all sparsifier-coo-check tests. Source tools/env.sh first.
#
# Tests 1-5 compare CSR vs COO outputs on common sparse ops (SpMM, scale,
# binary add, segmented reduce, weighted SpMM). Test 6 attempts GPU codegen
# on COO directly. Test 7 demonstrates the COO → CSR conversion path.

set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT="$HERE/dumps"
mkdir -p "$OUT"

: "${LLVM_BUILD:?source tools/env.sh first}"

CUDA_RT="$LLVM_BUILD/lib/libmlir_cuda_runtime.so"
C_RT="$LLVM_BUILD/lib/libmlir_c_runner_utils.so"
RT="$LLVM_BUILD/lib/libmlir_runner_utils.so"

GPU_TARGET='gpu-triple=nvptx64-nvidia-cuda gpu-chip=sm_89 gpu-features=+ptx80 gpu-format=fatbin'
CPU_OPTS='enable-runtime-library=true'
GPU_CODEGEN_OPTS="enable-runtime-library=false parallelization-strategy=dense-outer-loop gpu-num-threads=128 $GPU_TARGET"
GPU_LIBGEN_OPTS="enable-runtime-library=true enable-gpu-libgen $GPU_TARGET"

# Lower + run a single test.
run_one() {
    local name=$1 src=$2 opts=$3 libs=$4
    mlir-opt "$src" --sparsifier="$opts" 2>"$OUT/$name.stderr.txt" >"$OUT/$name.lowered.mlir"
    if [[ ! -s "$OUT/$name.lowered.mlir" ]]; then
        echo "    LOWERING FAILED: $name (see $name.stderr.txt)"
        return 1
    fi
    if [[ "$libs" == "cuda" ]]; then
        mlir-runner --shared-libs="$CUDA_RT" --shared-libs="$C_RT" --shared-libs="$RT" \
            -e main --entry-point-result=void "$OUT/$name.lowered.mlir" \
            >"$OUT/$name.out.txt" 2>&1
    else
        mlir-runner --shared-libs="$C_RT" --shared-libs="$RT" \
            -e main --entry-point-result=void "$OUT/$name.lowered.mlir" \
            >"$OUT/$name.out.txt" 2>&1
    fi
    if grep -q 'JIT session error\|Failed to materialize' "$OUT/$name.out.txt"; then
        echo "    EXEC FAILED: $name"
        return 2
    fi
    return 0
}

# Compare two outputs ignoring storage-layout noise. For dense outputs
# (printMemrefF32), strip the memref base-address header. For sparse
# outputs (sparse_tensor.print), the pos/crd arrays legitimately differ
# between CSR and COO storage — extract only the values + nse lines,
# which DO have to match between the two formats for the same logical
# tensor.
diff_outputs() {
    local a=$1 b=$2
    if grep -q '^---- Sparse Tensor' "$OUT/$a.out.txt"; then
        # sparse_tensor.print output — compare nse + values only
        diff <(grep -E '^nse|^values' "$OUT/$a.out.txt") \
             <(grep -E '^nse|^values' "$OUT/$b.out.txt") >/dev/null
    else
        diff <(grep -v 'Unranked' "$OUT/$a.out.txt") \
             <(grep -v 'Unranked' "$OUT/$b.out.txt") >/dev/null
    fi
}

run_pair() {
    local label=$1 csr_src=$2 coo_src=$3
    echo "=== $label ==="
    local base=$(basename "$csr_src" -csr.mlir)
    run_one "$base-csr" "$csr_src" "$CPU_OPTS" cpu
    run_one "$base-coo" "$coo_src" "$CPU_OPTS" cpu
    if diff_outputs "$base-csr" "$base-coo"; then
        echo "  CSR vs COO: IDENTICAL"
    else
        echo "  CSR vs COO: DIFFERS"
    fi
}

run_pair "Test 1: SpMM" \
    "$HERE/01-spmm-csr.mlir" "$HERE/01-spmm-coo.mlir"
run_pair "Test 2: Sparse-in-place scale" \
    "$HERE/02-scale-csr.mlir" "$HERE/02-scale-coo.mlir"
run_pair "Test 3: Sparse+sparse binary add" \
    "$HERE/03-binary-csr.mlir" "$HERE/03-binary-coo.mlir"
run_pair "Test 4: Per-row sum reduction" \
    "$HERE/04-segreduce-csr.mlir" "$HERE/04-segreduce-coo.mlir"
run_pair "Test 5: Weighted SpMM (non-square dense operand)" \
    "$HERE/05-spmm-weighted-csr.mlir" "$HERE/05-spmm-weighted-coo.mlir"

echo
echo "=== Test 6: GPU codegen on COO directly ==="
for strat in dense-outer-loop any-storage-outer-loop; do
    name="06-spmm-gpu-coo-$strat"
    mlir-opt "$HERE/06-spmm-gpu-coo.mlir" \
        --sparsifier="enable-runtime-library=false parallelization-strategy=$strat gpu-num-threads=128 $GPU_TARGET" \
        2>"$OUT/$name.stderr.txt" >"$OUT/$name.lowered.mlir"
    if [[ ! -s "$OUT/$name.lowered.mlir" ]]; then
        echo "  $strat: LOWERING FAILED"; continue
    fi
    gpu_ops=$(grep -c 'gpu\.binary\|llvm\.call @mgpu' "$OUT/$name.lowered.mlir")
    echo "  $strat: $gpu_ops GPU ops emitted (gpu.binary + mgpu* calls)"
done

echo
echo "=== Test 7: COO → in-MLIR CSR convert → SpMM ==="
mlir-opt "$HERE/07-coo-to-csr-then-spmm.mlir" --sparsifier="$GPU_CODEGEN_OPTS" \
    2>"$OUT/07-gpu.stderr.txt" >"$OUT/07-gpu.lowered.mlir"
gpu_ops=$(grep -c 'gpu\.binary\|llvm\.call @mgpu' "$OUT/07-gpu.lowered.mlir")
echo "  GPU ops emitted: $gpu_ops"
run_one 07-gpu "$HERE/07-coo-to-csr-then-spmm.mlir" "$GPU_CODEGEN_OPTS" cuda
if diff_outputs 01-spmm-csr 07-gpu; then
    echo "  Test 7 GPU output IDENTICAL to Test 1 CSR baseline"
else
    echo "  Test 7 GPU output DIFFERS from Test 1 CSR"
fi
