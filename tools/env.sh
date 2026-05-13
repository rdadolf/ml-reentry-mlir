# Source from bash: `source tools/env.sh`.
#
# Exports paths to the locally-built LLVM and torch-mlir, and puts mlir-opt,
# FileCheck, llvm-lit, etc. on PATH. Python bindings for both projects go on
# PYTHONPATH.
#
# Requires GNNC_CACHE_DIR set (devcontainer sets this).

if [[ -z "${GNNC_CACHE_DIR:-}" ]]; then
    echo "tools/env.sh: GNNC_CACHE_DIR not set — are you in the devcontainer?" >&2
    return 1
fi

export LLVM_BUILD="$GNNC_CACHE_DIR/build/llvm"
export TORCH_MLIR_BUILD="$GNNC_CACHE_DIR/build/torch-mlir"

if [[ -d "$LLVM_BUILD/bin" ]]; then
    case ":$PATH:" in
        *":$LLVM_BUILD/bin:"*) ;;
        *) export PATH="$LLVM_BUILD/bin:$PATH" ;;
    esac
fi

# torch-mlir wheel-style Python package directory (post-build).
TM_PY="$TORCH_MLIR_BUILD/tools/torch-mlir/python_packages/torch_mlir"
# Upstream MLIR Python bindings.
MLIR_PY="$LLVM_BUILD/tools/mlir/python_packages/mlir_core"

for p in "$TM_PY" "$MLIR_PY"; do
    if [[ -d "$p" ]]; then
        case ":${PYTHONPATH:-}:" in
            *":$p:"*) ;;
            *) export PYTHONPATH="$p${PYTHONPATH:+:$PYTHONPATH}" ;;
        esac
    fi
done

export FILECHECK="$LLVM_BUILD/bin/FileCheck"
