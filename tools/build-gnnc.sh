#!/usr/bin/env bash
# Configure and build gnnc's C++ MLIR passes against the cached LLVM/MLIR build.
#
# Preconditions:
#   - tools/build-llvm.sh has produced $GNNC_CACHE_DIR/build/llvm.
#   - third_party/llvm-project submodule checked out (MLIRConfig.cmake points at
#     its headers).
#
# Reads:  GNNC_CACHE_DIR — build root.
# Writes: $GNNC_CACHE_DIR/build/gnnc — cmake build dir (produces GNNCPlugin.so).

set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${GNNC_CACHE_DIR:?GNNC_CACHE_DIR not set — are you running inside the devcontainer?}"

LLVM_BUILD="$GNNC_CACHE_DIR/build/llvm"
LLVM_SRC="$REPO/third_party/llvm-project"
BUILD_DIR="$GNNC_CACHE_DIR/build/gnnc"

mkdir -p "$BUILD_DIR"

# Configure (+ preconditions + ABI guard) only when the build tree doesn't exist
# yet, or on `--reconfigure`. ninja re-runs CMake itself when CMakeLists.txt
# changes, so the common rebuild path below is pure `ninja` — no reconfigure and
# no guard. The SHA guard lives here because it only matters when (re)configuring
# against the cache; a warm rebuild trusts the existing configuration.
if [[ ! -f "$BUILD_DIR/build.ninja" || "${1:-}" == "--reconfigure" ]]; then
    if [[ ! -d "$LLVM_BUILD/lib/cmake/mlir" ]]; then
        echo "error: $LLVM_BUILD/lib/cmake/mlir missing — run tools/build-llvm.sh first" >&2
        exit 1
    fi
    if [[ ! -d "$LLVM_SRC/mlir/include" ]]; then
        echo "error: $LLVM_SRC/mlir/include missing — run 'git submodule update --init third_party/llvm-project'" >&2
        exit 1
    fi

    # ---- ABI guard: cached libs and submodule headers must be the same SHA ----
    # MLIR has no stable C++ ABI; mismatched source headers vs prebuilt libs
    # compile and link cleanly but corrupt at runtime. Compare the SHA the cache
    # was built from (recorded in the generated VCSRevision.h) against the
    # checked-out submodule HEAD. Both are read live — no SHA is hardcoded here.
    vcs="$LLVM_BUILD/include/llvm/Support/VCSRevision.h"
    [[ -f "$vcs" ]] || vcs=$(find "$LLVM_BUILD" -path '*/llvm/Support/VCSRevision.h' -print -quit 2>/dev/null || true)
    if [[ -z "$vcs" || ! -f "$vcs" ]]; then
        echo "error: VCSRevision.h not found under $LLVM_BUILD — is the LLVM build complete?" >&2
        exit 1
    fi
    build_sha=$(grep LLVM_REVISION "$vcs" | grep -oE '[0-9a-f]{40}' | head -1 || true)
    src_sha=$(git -C "$LLVM_SRC" rev-parse HEAD)
    if [[ -z "$build_sha" ]]; then
        echo "error: could not parse LLVM_REVISION from $vcs" >&2
        exit 1
    fi
    if [[ "$build_sha" != "$src_sha" ]]; then
        cat >&2 <<EOF
error: LLVM cache/source SHA mismatch — refusing to configure (ABI risk).
  cached libs built from : $build_sha   ($vcs)
  submodule source HEAD  : $src_sha   ($LLVM_SRC)
MLIR has no stable C++ ABI; building gnnc against mismatched headers would
compile cleanly but corrupt at runtime. Re-checkout the submodule to match the
cache, or rebuild LLVM with tools/build-llvm.sh.
EOF
        exit 1
    fi
    # Advisory only: is the submodule at the commit the superproject pins?
    pinned_sha=$(git -C "$REPO" rev-parse HEAD:third_party/llvm-project 2>/dev/null || true)
    if [[ -n "$pinned_sha" && "$pinned_sha" != "$src_sha" ]]; then
        echo "warning: llvm-project submodule HEAD ($src_sha) != pinned index ($pinned_sha)" >&2
    fi

    # Same compiler/linker as the LLVM build — ABI flags must match. The venv
    # interpreter (with nanobind) drives the pass bridge's nanobind discovery,
    # the same way build-llvm.sh points the bindings build at it.
    cmake -G Ninja -S "$REPO" -B "$BUILD_DIR" \
        -DMLIR_DIR="$LLVM_BUILD/lib/cmake/mlir" \
        -DLLVM_EXTERNAL_LIT="$LLVM_BUILD/bin/llvm-lit" \
        -DMLIR_INCLUDE_TESTS=ON \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DLLVM_USE_LINKER=lld \
        -DPython3_EXECUTABLE="$(command -v python3)"
fi

### Fast path ###
# *Do not add anything here that (during a no-op build) would take a non-trivial
# amount of time.*
ninja -C "$BUILD_DIR"

# Symlink the built pass module next to the gnnc sources so
# `import gnnc._gnncRegisterPasses` resolves.
ext=$(echo "$BUILD_DIR/lib/_gnncRegisterPasses."*.so)
if [[ ! -f "$ext" ]]; then
    echo "error: build succeeded but $BUILD_DIR/lib/_gnncRegisterPasses.*.so is missing" >&2
    exit 1
fi
ln -sfn "$ext" "$REPO/gnnc/$(basename "$ext")"

echo
echo "gnnc C++ build complete: $BUILD_DIR"
echo "  GNNCPlugin.so:  $BUILD_DIR/lib/GNNCPlugin.so"
echo "  pass module:    $REPO/gnnc/$(basename "$ext")"
echo "  lit tests:      ninja -C $BUILD_DIR check-gnnc"
