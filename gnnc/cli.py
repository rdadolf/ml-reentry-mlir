"""gnnc CLI entry point.

`gnnc run` resolves a recipe (a Lighthouse YAML pipeline under
`gnnc/recipes/`) and validates it by parsing through Lighthouse's pipeline
descriptor — proving the gnnc → Lighthouse wiring. Wiring the full
ingress → recipe → runner execution path is a later phase (it needs the
GNN-specific `transform:` schedules and golden comparison).
"""

from __future__ import annotations

import argparse
import sys

from gnnc import __version__, paths, recipes


def _cmd_run(args: argparse.Namespace) -> int:
    print(f"gnnc {__version__}")
    print(f"  model    : {args.model}")
    print(f"  dataset  : {args.dataset}")
    print(f"  recipe   : {args.recipe}")
    print(f"  target   : {args.target}")
    print(f"  DATA_DIR : {paths.DATA_DIR}")
    print(f"  CACHE_DIR: {paths.CACHE_DIR}")

    try:
        recipe_path = recipes.resolve(args.recipe)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    try:
        stages = recipes.load(args.recipe)
    except ImportError as exc:
        print(
            f"error: cannot load recipe — Lighthouse/MLIR not importable: {exc}\n"
            "  (source tools/env.sh after building the LLVM/torch-mlir stack)",
            file=sys.stderr,
        )
        return 3

    print(f"  recipe ok: {recipe_path} ({len(stages)} stages)")
    for s in stages:
        print(f"    - {s}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="gnnc")
    parser.add_argument("--version", action="version", version=f"gnnc {__version__}")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_run = sub.add_parser("run", help="Compile and execute a GNN model")
    p_run.add_argument("--model", required=True, choices=["gcn", "sage", "gat"])
    p_run.add_argument("--dataset", required=True, choices=["cora", "ogbn-arxiv"])
    p_run.add_argument(
        "--recipe",
        required=True,
        help="Recipe name under gnnc/recipes (e.g. 'cpu/passthrough'). "
        f"Known: {recipes.available()}",
    )
    p_run.add_argument("--target", required=True, choices=["cpu", "cuda"])
    p_run.set_defaults(func=_cmd_run)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
