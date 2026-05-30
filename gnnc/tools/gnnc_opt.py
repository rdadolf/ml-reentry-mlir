"""gnnc-opt — apply gnnc's torch-dialect transforms / lowering to MLIR.

mlir-opt-style: read MLIR (file or stdin), apply the requested transformations in
order, write MLIR (stdout or `-o`). With no transform flags it echoes (parse +
print), like `mlir-opt`.

    gnnc-opt input.mlir --transform -o out.mlir
    gnnc model.py --dialect raw | gnnc-opt --transform --lower linalg-on-tensors

Input must be torch-dialect MLIR (e.g. the output of `gnnc <model> --dialect raw`).
`--lower` on raw input needs `--transform` first (otherwise torch.aten._sparse_mm
fails to legalize).
"""

from __future__ import annotations

import argparse
import sys

from gnnc.tools.util import (
    LOWER_DIALECTS,
    read_input,
    stack_unimportable_message,
    write_output,
)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="gnnc-opt", description="Apply gnnc torch-dialect transforms to MLIR."
    )
    parser.add_argument("input", nargs="?", default="-", help="Input .mlir (default: stdin)")
    parser.add_argument("-o", "--output", default="-", help="Output .mlir (default: stdout)")
    parser.add_argument(
        "--transform", action="store_true", help="Apply the gnnc torch-dialect rewrite pipeline"
    )
    parser.add_argument(
        "--lower",
        choices=LOWER_DIALECTS,
        help="Lower to this dialect (use --transform first on raw input)",
    )
    args = parser.parse_args(argv)

    text = read_input(args.input)

    try:
        from torch_mlir import ir
        from torch_mlir.dialects import torch as torch_d
    except ImportError as exc:
        print(stack_unimportable_message(exc), file=sys.stderr)
        return 3

    ctx = ir.Context()
    torch_d.register_dialect(ctx)  # required to parse torch.* ops
    module = ir.Module.parse(text, ctx)

    if args.transform:
        from gnnc.transform import run as run_transforms

        run_transforms(module)
    if args.lower:
        from gnnc.lowering import lower

        lower(module, args.lower)

    write_output(str(module), args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
