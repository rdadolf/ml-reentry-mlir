"""gnnc-bench — end-to-end compile + execute + reference comparison.

    gnnc-bench --model gcn --dataset cora --recipe cpu/passthrough --target cpu

Currently resolves a recipe (a Lighthouse YAML pipeline under `gnnc/recipes/`)
and validates it by parsing through Lighthouse's pipeline descriptor — proving
the gnnc -> Lighthouse wiring. Wiring the full ingress -> recipe -> runner
execution path is a later phase.

(Was `gnnc run`; moved to its own tool so `gnnc` itself is the model-file ->
MLIR emitter.)
"""

from __future__ import annotations

import argparse
import sys
from typing import TYPE_CHECKING

from gnnc import __version__, paths, recipes
from gnnc.tools.util import stack_unimportable_message

if TYPE_CHECKING:
    import numpy as np


def evaluate(
    model: str, dataset: str, *, recipe: str | None = None, target: str = "cpu"
) -> np.ndarray:
    """Compile `model` on `dataset` through `recipe` and execute, returning
    the output as a numpy array — for comparison against the known-good golden.

    NOT IMPLEMENTED. Wiring ingress -> transform -> recipe lowering -> Runner ->
    output array is the gnnc-bench buildout. The bench golden tests
    (`test/bench/`) are written against this signature and xfail until it lands.
    """
    raise NotImplementedError("gnnc-bench compile+execute is not implemented yet")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="gnnc-bench", description="Compile and execute a GNN model."
    )
    parser.add_argument("--model", required=True, choices=["gcn", "sage"])
    parser.add_argument("--dataset", required=True, choices=["cora", "ogbn-arxiv"])
    parser.add_argument(
        "--recipe",
        required=True,
        help=f"Recipe name under gnnc/recipes (e.g. 'cpu/passthrough'). Known: {recipes.available()}",
    )
    parser.add_argument("--target", required=True, choices=["cpu", "cuda"])
    args = parser.parse_args(argv)

    print(f"gnnc-bench {__version__}")
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
        print(stack_unimportable_message(exc), file=sys.stderr)
        return 3

    print(f"  recipe ok: {recipe_path} ({len(stages)} stages)")
    for s in stages:
        print(f"    - {s}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
