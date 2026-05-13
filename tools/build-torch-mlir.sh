#!/usr/bin/env bash
# Configure and build torch-mlir out-of-tree against the freshly-built LLVM.
#
# Preconditions:
#   - tools/build-llvm.sh has been run.
#   - torch-mlir submodule initialized at the pinned commit.
#
# Reads:
#   GNNC_CACHE_DIR — build/ccache root.

set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${GNNC_CACHE_DIR:?GNNC_CACHE_DIR not set — are you running inside the devcontainer?}"

TM_SRC="$REPO/third_party/torch-mlir"
LLVM_BUILD="$GNNC_CACHE_DIR/build/llvm"
BUILD_DIR="$GNNC_CACHE_DIR/build/torch-mlir"

if [[ ! -d "$TM_SRC" ]]; then
    echo "error: $TM_SRC missing — run 'git submodule update --init third_party/torch-mlir'" >&2
    exit 1
fi
if [[ ! -d "$LLVM_BUILD/lib/cmake/mlir" ]]; then
    echo "error: $LLVM_BUILD/lib/cmake/mlir missing — run tools/build-llvm.sh first" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"

# torch-mlir's out-of-tree build pattern. See torch-mlir/docs/development.md
# for the canonical recipe; mirror it here.
cmake -G Ninja -S "$TM_SRC" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DMLIR_DIR="$LLVM_BUILD/lib/cmake/mlir" \
    -DLLVM_DIR="$LLVM_BUILD/lib/cmake/llvm" \
    -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
    -DTORCH_MLIR_ENABLE_STABLEHLO=OFF \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DLLVM_ENABLE_LLD=ON \
    -DLLVM_CCACHE_BUILD=ON \
    -DPython3_EXECUTABLE="$(command -v python3)"

ninja -C "$BUILD_DIR"

echo
echo "torch-mlir build complete: $BUILD_DIR"
echo "Source tools/env.sh to put torch_mlir on PYTHONPATH."
