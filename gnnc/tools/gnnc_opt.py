"""gnnc-opt — run gnnc phases and passes on MLIR, mlir-opt style.

Read MLIR (file or stdin) in Lighthouse's context, run the requested work, write
MLIR (stdout or `-o`). Two ways to say what to run:

    gnnc-opt input.mlir --phase sparsify              # one named schedule phase
    gnnc-opt input.mlir --pass sparse-assembler --pass convert-to-llvm
    gnnc-opt input.mlir --pass gnnc-assert-reshape-encoding   # a gnnc Python pass

A pass name is resolved as a gnnc Python pass if one is registered under it
(see `gnnc.passes`), otherwise as a C++/upstream pass the PassManager knows.
`--pass` repeats and accepts comma-separated lists. With neither flag, the input
is parsed and reprinted (a round-trip check).

Phases are the schedule phases (`gnnc.schedule`); `--list-py-passes` lists the
gnnc `--pass` names. There is no phase listing — phases vary with `--target`, so
an unknown `--phase` instead reports the valid ones for the configuration.
Pass failures (e.g. an assertion pass firing) print diagnostics to stderr and
exit non-zero.
"""

from __future__ import annotations

import argparse
import sys


def _schedule(target: str):
    from gnnc.schedule.sparse import build_pipeline

    return build_pipeline(target=target)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="gnnc-opt", description="Run gnnc phases and passes on MLIR."
    )
    parser.add_argument("input", nargs="?", default="-", help="Input .mlir (default: stdin)")
    parser.add_argument("-o", "--output", default="-", help="Output .mlir (default: stdout)")
    parser.add_argument(
        "--target", default="cpu", choices=("cpu", "gpu"), help="Schedule target (default: cpu)"
    )

    what = parser.add_mutually_exclusive_group()
    what.add_argument("--phase", metavar="NAME", help="Run the named schedule phase")
    what.add_argument(
        "--pass",
        dest="passes",
        action="append",
        default=[],
        metavar="PASS[,PASS...]",
        help="Run a pass by name (repeatable; comma-separated allowed)",
    )

    parser.add_argument(
        "--list-py-passes", action="store_true", help="List registered gnnc Python passes and exit"
    )
    args = parser.parse_args(argv)

    if args.list_py_passes:
        from gnnc.passes import registry

        for name in registry.names():
            print(name)
        return 0

    pass_list = [spec for chunk in args.passes for spec in chunk.split(",") if spec]

    from gnnc.tools.util import read_input, write_output

    text = read_input(args.input)

    try:
        from mlir import ir

        from gnnc import get_context
    except ImportError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3

    ctx = get_context()
    with ctx, ir.Location.unknown():
        module = ir.Module.parse(text)

        phase = None
        if args.phase:
            schedule = _schedule(args.target)
            phase = schedule.find(args.phase)
            if phase is None:
                print(
                    f"error: unknown phase {args.phase!r}; phases: {schedule.names()}",
                    file=sys.stderr,
                )
                return 2
        elif pass_list:
            from gnnc.pipeline.phase import StagePhase

            phase = StagePhase("<cli>")
            for spec in pass_list:
                phase.add_pass(spec)

        if phase is not None:
            module = phase.run(module, lambda: ctx)

        out = str(module)

    write_output(out, args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
