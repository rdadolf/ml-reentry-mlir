"""gnnc-import — import a PyG model file and lower it through compilation phases.

    gnnc-import path/to/model.py [--stop-after PHASE] [-o out.mlir]

One of gnnc's model front-ends: it emits IR, not a binary. The transformation
is a linear sequence of named phases; halt at any boundary to capture the IR
there.

    gnnc-import model.py --stop-after import          # pristine FX import
    gnnc-import model.py --stop-after torch-legalize   # torch dialect
    gnnc-import model.py --stop-after linalg-lower      # linalg-on-tensors
    gnnc-import model.py --stop-after sparsify -o s.mlir

(`--stop-after import|torch-legalize|linalg-lower` replace the old
`--dialect raw|torch|linalg-on-tensors`.)

`--trace` runs and then reports the phases and passes that actually ran —
provably correct for the given flags/model/target, where a static listing would
only be a guess (phases can be defined conditionally).

End-to-end compile + execute + reference comparison lives in `gnnc-bench`.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="gnnc-import", description="Import a PyG model file and lower it through phases."
    )
    parser.add_argument(
        "model_file", help="Path to a model .py (Model + get_init_inputs + get_inputs)"
    )
    parser.add_argument(
        "-o", "--output", default="-", help="Output path for the MLIR (default: stdout)"
    )
    parser.add_argument(
        "--target", default="cpu", choices=("cpu", "gpu"), help="Schedule target (default: cpu)"
    )

    halt = parser.add_argument_group("phase control")
    halt.add_argument("--stop-before", metavar="PHASE", help="Run up to, not including, PHASE")
    halt.add_argument("--stop-after", metavar="PHASE", help="Run up to and including PHASE")
    halt.add_argument(
        "--print-ir-before",
        action="append",
        default=[],
        metavar="PHASE",
        help="Print IR before PHASE (to stderr; repeatable)",
    )
    halt.add_argument(
        "--print-ir-after",
        action="append",
        default=[],
        metavar="PHASE",
        help="Print IR after PHASE (to stderr; repeatable)",
    )

    parser.add_argument(
        "--trace",
        action="store_true",
        help="After running, print the phases and passes that ran (to stderr)",
    )
    args = parser.parse_args(argv)

    if not Path(args.model_file).is_file():
        print(f"error: no such model file: {args.model_file}", file=sys.stderr)
        return 2

    from gnnc.pipeline.phase import PhaseNotReached
    from gnnc.tools.util import write_output

    try:
        from gnnc.compile import lower
        from gnnc.ingress import get_model_and_data

        model, forward_inputs = get_model_and_data(Path(args.model_file))
        module, trace = lower(
            model,
            forward_inputs,
            target=args.target,
            stop_before=args.stop_before,
            stop_after=args.stop_after,
            print_ir_before=frozenset(args.print_ir_before),
            print_ir_after=frozenset(args.print_ir_after),
            emit=lambda text: print(text, file=sys.stderr),
        )
    except ImportError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3
    except (PhaseNotReached, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if module is None:
        print("error: no phases ran (the stop excluded everything)", file=sys.stderr)
        return 2

    write_output(str(module), args.output)

    if args.trace:
        print("// -----// Trace //----- //", file=sys.stderr)
        for name, passes in trace:
            print(name, file=sys.stderr)
            for spec in passes:
                print(f"    {spec}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
