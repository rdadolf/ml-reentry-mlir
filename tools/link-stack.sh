#!/usr/bin/env bash
# Link the source-built Python stack into the venv's site-packages, so every
# consumer on the venv interpreter — the CLIs, pytest, lit, Pylance — imports
# torch_mlir / mlir / lighthouse without PYTHONPATH. Idempotent (ln -sfn just
# relinks). Run after the builds + venv exist; re-run only after a venv recreate,
# a new stack package, or a GNNC_CACHE_DIR move (uv sync does NOT disturb these).
#
# Loosely adapted from IREE's editable install, minus the niceties of actually
# being one (https://iree.dev/building-from-source/getting-started/).

set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${GNNC_CACHE_DIR:?GNNC_CACHE_DIR not set — are you running inside the devcontainer?}"

SITE=$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')
[[ -d "$SITE" ]] || { echo "error: venv site-packages not found (got '$SITE')" >&2; exit 1; }

# name -> source-built package dir. Single source of truth for the stack.
# mlir/torch_mlir live in the shared cache; lighthouse is per-worktree.
declare -A STACK=(
    [mlir]="$GNNC_CACHE_DIR/build/llvm/tools/mlir/python_packages/mlir_core/mlir"
    [torch_mlir]="$GNNC_CACHE_DIR/build/torch-mlir/python_packages/torch_mlir/torch_mlir"
    [lighthouse]="$REPO/third_party/lighthouse/lighthouse"
)

for name in "${!STACK[@]}"; do
    target=${STACK[$name]}
    link="$SITE/$name"
    if [[ -e "$link" && ! -L "$link" ]]; then
        echo "warning: $link is a real package, not a symlink — skipping" >&2
        continue
    fi
    if [[ ! -e "$target" ]]; then
        echo "warning: $name target missing, skipping: $target" >&2
        continue
    fi
    ln -sfn "$target" "$link"
    echo "linked  $name -> $target"
done

# The _gnncRegisterPasses module is a single compiled extension rather than a
# package directory, so it is linked separately: place it next to the gnnc
# Python sources so `import gnnc._gnncRegisterPasses` resolves, which registers
# gnnc's C++ passes. Built by build-gnnc.sh into the gnnc build's lib/. Skipped
# with a warning if the C++ build has not run; the Python package still works,
# only without gnnc's C++ passes.
ext=$(echo "$GNNC_CACHE_DIR/build/gnnc/lib/_gnncRegisterPasses."*.so)
if [[ -f "$ext" ]]; then
    ln -sfn "$ext" "$REPO/gnnc/$(basename "$ext")"
    echo "linked  gnnc/$(basename "$ext") -> $ext"
else
    echo "warning: gnnc C++ pass module not built, skipping: run tools/build-gnnc.sh" >&2
fi
