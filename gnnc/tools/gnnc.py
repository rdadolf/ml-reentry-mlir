"""gnnc — compile a PyG model file to MLIR.

    gnnc path/to/model.py [--dialect raw] [-o out.mlir]

Flow: ingress (raw torch-dialect import) -> gnnc.transform (torch rewrites, for
any non-raw dialect) -> torch-mlir lowering to the requested dialect.

  raw                : pristine FX import (torch.aten._sparse_mm, no rewrites)
  torch              : after rewrites + torch-backend legalization
  linalg-on-tensors  : + lowering to linalg (tosa / stablehlo likewise)

End-to-end compile + execute + reference comparison lives in `gnnc-bench`.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from gnnc.tools.util import DIALECTS, stack_unimportable_message, write_output


def _emit(model_file: str, dialect: str) -> str:
    from gnnc.ingress.importer import import_model_module

    module = import_model_module(model_file)  # raw torch-dialect import
    if dialect == "raw":
        return str(module)

    from gnnc.lowering import lower
    from gnnc.transform import run as run_transforms

    run_transforms(module)  # canonicalize torch dialect (e.g. _sparse_mm -> mm)
    lower(module, dialect)
    return str(module)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="gnnc", description="Compile a PyG model file to MLIR.")
    parser.add_argument(
        "model_file", help="Path to a model .py (Model + get_init_inputs + get_inputs)"
    )
    parser.add_argument(
        "--dialect", default="raw", choices=list(DIALECTS), help="Output dialect (default: raw)"
    )
    parser.add_argument(
        "-o", "--output", default="-", help="Output path for the MLIR (default: stdout)"
    )
    args = parser.parse_args(argv)

    if not Path(args.model_file).is_file():
        print(f"error: no such model file: {args.model_file}", file=sys.stderr)
        return 2

    try:
        text = _emit(args.model_file, args.dialect)
    except ImportError as exc:
        print(stack_unimportable_message(exc), file=sys.stderr)
        return 3

    write_output(text, args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
