#!/usr/bin/env bash
# Source-build and install the PyG library set into the active venv.
#
# Builds: pytorch_scatter, pytorch_sparse, pyg-lib. These are the
# "pip install pytorch-geometric"-deployment-path optional libraries — they
# provide the CUDA kernels behind PyG's MessagePassing / SparseTensor paths.
# Published wheels at https://data.pyg.org/whl/ lag PyTorch nightlies, so we
# build from the master pins recorded in third_party/README.md.
#
# Reads:
#   GNNC_CACHE_DIR — for incidental disk space; pip's ephemeral build dir is
#                    used because these builds are fast enough.
#   CUDA_HOME (optional) — defaults to /usr/local/cuda inside the devcontainer.
# Writes:
#   Installs three Python packages into $UV_PROJECT_ENVIRONMENT.

set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${GNNC_CACHE_DIR:?GNNC_CACHE_DIR not set — are you running inside the devcontainer?}"

# RTX 4070 is sm_89 (Ada Lovelace). Restrict to this single arch to keep
# the build fast; expand if multi-GPU support is ever needed.
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.9}"
export FORCE_CUDA="${FORCE_CUDA:-1}"
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"

# Cap parallelism. nvcc compiling cutlass-heavy CUDA template code can use
# 6-10 GiB per process; on a 15 GiB box, default `ninja -j$(nproc)` OOMs
# (specifically pyg-lib's fps_kernel.cu / matmul_kernel.cu). 4 parallel
# jobs leaves comfortable headroom.
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-4}"
export MAX_JOBS="${MAX_JOBS:-4}"

if [[ ! -d "$CUDA_HOME" ]]; then
    echo "error: CUDA_HOME=$CUDA_HOME does not exist" >&2
    exit 1
fi

# Sanity: ensure each submodule is initialized.
for d in pytorch_scatter pytorch_sparse pyg-lib; do
    if [[ ! -e "$REPO/third_party/$d/setup.py" && ! -e "$REPO/third_party/$d/CMakeLists.txt" ]]; then
        echo "error: third_party/$d not initialized — run 'git submodule update --init --recursive'" >&2
        exit 1
    fi
done

# All three have their own submodules (parallel-hashmap for sparse;
# METIS/cutlass/cccl/cuCollections/parallel-hashmap for pyg-lib).
for d in pytorch_scatter pytorch_sparse pyg-lib; do
    git -C "$REPO/third_party/$d" submodule update --init --recursive --quiet
done

echo "==> Building pytorch_scatter"
uv pip install --no-build-isolation "$REPO/third_party/pytorch_scatter"

echo "==> Building pytorch_sparse"
uv pip install --no-build-isolation "$REPO/third_party/pytorch_sparse"

echo "==> Building pyg-lib"
uv pip install --no-build-isolation "$REPO/third_party/pyg-lib"

echo
echo "Done. Verify dispatch flags:"
echo "  python -c 'import torch_geometric.typing as t; print(t.WITH_TORCH_SCATTER, t.WITH_TORCH_SPARSE, t.WITH_PYG_LIB)'"
