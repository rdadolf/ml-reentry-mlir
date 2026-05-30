"""Command-line entry points: `gnnc`, `gnnc-opt`, `gnnc-bench`.

Each tool is a thin argparse + dispatch shim; shared CLI plumbing (dialect
choices, stdin/stdout file I/O, the stack-not-importable error message) lives
in [util.py](util.py).
"""
