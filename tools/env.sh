# Source from bash: `source tools/env.sh`.
#
# Interactive convenience only: puts the locally-built LLVM tools (mlir-opt,
# FileCheck, llvm-lit, ...) on PATH so you can run them by name in a shell.
#
# The Python stack (torch_mlir / mlir / lighthouse) is NOT handled here any more
# — it lives in the venv's site-packages via tools/link-stack.sh, so the CLIs,
# pytest, lit, and Pylance resolve it with no PYTHONPATH. Nothing automated
# depends on sourcing this; it's purely for typing tool names by hand.
#
# Requires GNNC_CACHE_DIR set (the devcontainer sets this).

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

export FILECHECK="$LLVM_BUILD/bin/FileCheck"
