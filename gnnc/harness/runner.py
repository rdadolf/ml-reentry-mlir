"""Drive mlir-runner with the appropriate runtime libraries.

Locates binaries via $LLVM_BUILD (set by .devcontainer/Dockerfile and
tools/env.sh) and shared libs via $LLVM_BUILD/lib. Real implementation lands
in week 1.
"""

from __future__ import annotations


def run(*args, **kwargs):  # noqa: ARG001
    raise NotImplementedError("runner.run lands in week 1")
