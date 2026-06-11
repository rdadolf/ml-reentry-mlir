"""Shared helpers for the `gnnc-import` / `gnnc-opt` / `gnnc-bench` CLIs.

Centralizes the bits all three repeat: the dialect list and stdin/stdout file
I/O. Keeping each tool a thin argparse + dispatch layer.
"""

from __future__ import annotations

import sys
from pathlib import Path

# torch-mlir's `OutputType.*` values in CLI form. `raw` is the pristine FX
# import (pre-legalization); the rest are torch-mlir lowering targets.
#
# Snapshotted here (rather than imported from `torch_mlir.fx.OutputType`) so
# argparse can list them as `--dialect` choices without paying the torch-mlir
# import cost at `--help` / arg-parse time. Lighthouse's own narrower
# `TargetDialect` enum (`lighthouse/ingress/torch/compile.py`) excludes `raw`
# and `torch`, which gnnc needs, so we can't reuse that either.
DIALECTS = ("raw", "torch", "linalg-on-tensors", "tosa", "stablehlo")

# Subset valid as a lowering target. `raw` is the input shape, never a target.
LOWER_DIALECTS = DIALECTS[1:]


def read_input(path: str) -> str:
    """`-` -> stdin; otherwise read the file at `path`."""
    return sys.stdin.read() if path == "-" else Path(path).read_text()


def write_output(text: str, path: str) -> None:
    """`-` -> stdout (with trailing newline); otherwise write to the file."""
    if path == "-":
        print(text)
    else:
        Path(path).write_text(text)
