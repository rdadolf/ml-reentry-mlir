#!/usr/bin/env bash
# Configure and build LLVM + MLIR out-of-tree on the cache mount.
#
# Reads:
#   GNNC_CACHE_DIR (set in devcontainer) — build/ccache root.
# Writes:
#   $GNNC_CACHE_DIR/build/llvm/   — build directory.
#
# First build: 30-90 min depending on cores. Subsequent builds: ccache hits.

set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${GNNC_CACHE_DIR:?GNNC_CACHE_DIR not set — are you running inside the devcontainer?}"

LLVM_SRC="$REPO/third_party/llvm-project/llvm"
BUILD_DIR="$GNNC_CACHE_DIR/build/llvm"

if [[ ! -d "$LLVM_SRC" ]]; then
    echo "error: $LLVM_SRC missing — run 'git submodule update --init third_party/llvm-project'" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"

# Target NVPTX for GPU codegen. sm_89 is the host's RTX 4070 (Ada Lovelace).
# CMAKE_CUDA_ARCHITECTURES is only consulted if any sub-project actually
# builds CUDA code; for MLIR it's mostly informational.
cmake -G Ninja -S "$LLVM_SRC" -B "$BUILD_DIR" \
    -DLLVM_ENABLE_PROJECTS="mlir" \
    -DLLVM_TARGETS_TO_BUILD="Native;NVPTX" \
    -DMLIR_ENABLE_CUDA_RUNNER=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_BUILD_EXAMPLES=ON \
    -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
    -DLLVM_ENABLE_LLD=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DLLVM_CCACHE_BUILD=ON \
    -DLLVM_INSTALL_UTILS=ON \
    -DPython3_EXECUTABLE="$(command -v python3)" \
    -DCMAKE_CUDA_ARCHITECTURES="89"

ninja -C "$BUILD_DIR"

echo
echo "LLVM build complete: $BUILD_DIR"
echo "  mlir-opt:    $BUILD_DIR/bin/mlir-opt"
echo "  mlir-runner: $BUILD_DIR/bin/mlir-runner"
echo "  FileCheck:   $BUILD_DIR/bin/FileCheck"
echo "Source tools/env.sh to add these to PATH."
