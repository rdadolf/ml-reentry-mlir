"""Shared helpers for the `gnnc-import` / `gnnc-opt` / `gnnc-bench` CLIs.

Centralizes the stdin/stdout file I/O the tools repeat, keeping each a thin
argparse + dispatch layer.
"""

from __future__ import annotations

import sys
from pathlib import Path


def read_input(path: str) -> str:
    """`-` -> stdin; otherwise read the file at `path`."""
    return sys.stdin.read() if path == "-" else Path(path).read_text()


def write_output(text: str, path: str) -> None:
    """`-` -> stdout (with trailing newline); otherwise write to the file."""
    if path == "-":
        print(text)
    else:
        Path(path).write_text(text)
