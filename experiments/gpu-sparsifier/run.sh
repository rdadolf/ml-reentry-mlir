#!/usr/bin/env bash
# Day-0 Task 2 driver. Runs three pipelines over an 8x8 SpMM and writes
# lowered IR + stdout for each into dumps/. Source tools/env.sh first.
#
#   cpu          CPU sparsifier (runtime library), baseline for correctness
#   gpu-libgen   GPU via --enable-gpu-libgen (cuSPARSE wrappers)
#   gpu-codegen  Direct GPU codegen via --gpu-num-threads=N

set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT="$HERE/dumps"
mkdir -p "$OUT"

: "${LLVM_BUILD:?source tools/env.sh first}"

CUDA_RT="$LLVM_BUILD/lib/libmlir_cuda_runtime.so"
C_RT="$LLVM_BUILD/lib/libmlir_c_runner_utils.so"
RT="$LLVM_BUILD/lib/libmlir_runner_utils.so"

# GPU target — RTX 4070 is sm_89 (Ada). +ptx80 unlocks the codegen features
# the sparsifier emits. gpu-format=fatbin embeds CUBIN+PTX, JIT-fallback safe.
GPU_TARGET='gpu-triple=nvptx64-nvidia-cuda gpu-chip=sm_89 gpu-features=+ptx80 gpu-format=fatbin'

run_one() {
    local name=$1 src=$2 sparsifier_opts=$3
    echo "=== $name ==="
    echo "  sparsifier opts: $sparsifier_opts"
    mlir-opt "$src" --sparsifier="$sparsifier_opts" 2>"$OUT/$name.lowered.stderr.txt" \
        >"$OUT/$name.lowered.mlir"
    if [[ ! -s "$OUT/$name.lowered.mlir" ]]; then
        echo "  LOWERING FAILED. See $name.lowered.stderr.txt"
        return 1
    fi
    mlir-runner \
        --shared-libs="$CUDA_RT" \
        --shared-libs="$C_RT" \
        --shared-libs="$RT" \
        -e main --entry-point-result=void \
        "$OUT/$name.lowered.mlir" >"$OUT/$name.out.txt" 2>&1
    if grep -q 'JIT session error\|Failed to materialize' "$OUT/$name.out.txt"; then
        echo "  EXECUTION FAILED. See $name.out.txt"
        return 2
    fi
    echo "  ok ($(wc -l <"$OUT/$name.out.txt") lines of output)"
    return 0
}

run_one cpu          "$HERE/spmm-cpu.mlir" "enable-runtime-library=true"
run_one gpu-libgen   "$HERE/spmm-gpu.mlir" "enable-runtime-library=true enable-gpu-libgen $GPU_TARGET"
run_one gpu-codegen  "$HERE/spmm-cpu.mlir" "enable-runtime-library=false parallelization-strategy=dense-outer-loop gpu-num-threads=128 $GPU_TARGET"

echo
echo "=== correctness check ==="
for variant in gpu-codegen gpu-libgen; do
    if [[ -s "$OUT/$variant.out.txt" ]] && grep -q '\[\[' "$OUT/$variant.out.txt"; then
        if diff -q <(grep -v '^Unranked' "$OUT/cpu.out.txt") \
                  <(grep -v '^Unranked' "$OUT/$variant.out.txt") >/dev/null; then
            echo "  $variant: BIT-IDENTICAL with cpu"
        else
            echo "  $variant: differs from cpu"
        fi
    else
        echo "  $variant: did not produce output, skipping diff"
    fi
done
