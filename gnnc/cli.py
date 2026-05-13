"""gnnc CLI entry point.

Currently a placeholder that prints a resolved-config block. Week-1 wires the
ingress → recipe → runner pipeline behind `gnnc run`.
"""

from __future__ import annotations

import argparse
import sys

from gnnc import __version__, paths
from gnnc.harness import recipes


def _cmd_run(args: argparse.Namespace) -> int:
    print(f"gnnc {__version__}")
    print(f"  model    : {args.model}")
    print(f"  dataset  : {args.dataset}")
    print(f"  recipe   : {args.recipe}")
    print(f"  target   : {args.target}")
    print(f"  DATA_DIR : {paths.DATA_DIR}")
    print(f"  CACHE_DIR: {paths.CACHE_DIR}")
    if args.recipe not in recipes.RECIPES:
        print(f"error: recipe '{args.recipe}' not registered", file=sys.stderr)
        print(f"  known recipes: {sorted(recipes.RECIPES)}", file=sys.stderr)
        return 2
    print(f"  recipe ok: {recipes.RECIPES[args.recipe].__doc__ or '(no docstring)'}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="gnnc")
    parser.add_argument("--version", action="version", version=f"gnnc {__version__}")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_run = sub.add_parser("run", help="Compile and execute a GNN model")
    p_run.add_argument("--model", required=True, choices=["gcn", "sage", "gat"])
    p_run.add_argument("--dataset", required=True, choices=["cora", "ogbn-arxiv"])
    p_run.add_argument("--recipe", required=True)
    p_run.add_argument("--target", required=True, choices=["cpu", "cuda"])
    p_run.set_defaults(func=_cmd_run)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
