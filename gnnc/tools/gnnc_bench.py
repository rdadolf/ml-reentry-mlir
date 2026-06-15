"""gnnc-bench: compile a model, execute it, compare to torch.

    gnnc-bench --model mlp
    gnnc-bench --model gcn --dataset cora
    gnnc-bench --model gcn --dataset cora --target gpu

Resolves `--model` to a file under `gnnc/examples/models/`, runs the gnnc
compile pipeline for the `--target`, JIT-executes via Lighthouse's
`JITFunction`, and compares the output against a torch run of the same model.

Omit `--dataset` for non-graph models (e.g. the MLP) — the model file's
own `get_inputs()` is used. Named datasets (`cora`, `ogbn-arxiv`) override
the inputs with real graph data and re-shape the model's `in/out_channels`
to match.
"""

from __future__ import annotations

import argparse
import sys

import numpy as np

from gnnc import __version__, paths
from gnnc.examples import MODELS_DIR, available
from gnnc.ingress import get_model_and_data


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="gnnc-bench",
        description="Compile a model and compare its output to torch eager.",
    )
    parser.add_argument("--model", required=True, choices=available())
    parser.add_argument(
        "--dataset",
        default=None,
        choices=["cora", "ogbn-arxiv"],
        help="Optional real-dataset inputs; omit for synthetic get_inputs().",
    )
    parser.add_argument(
        "--target", default="cpu", choices=("cpu", "gpu"), help="Schedule target (default: cpu)"
    )
    args = parser.parse_args(argv)

    print(f"gnnc-bench {__version__}")
    print(f"  model    : {args.model}")
    print(f"  dataset  : {args.dataset or '<synthetic>'}")
    print(f"  target   : {args.target}")
    print(f"  DATA_DIR : {paths.DATA_DIR}")

    try:
        import torch

        from gnnc.compile import compile_executable
        from gnnc.execution import run_jit

        model, forward_inputs = get_model_and_data(MODELS_DIR / f"{args.model}.py", args.dataset)
        model.eval()
        with torch.no_grad():
            ref = model(*forward_inputs).cpu().numpy()
        lowered, results = compile_executable(model, forward_inputs, target=args.target)
        outs = run_jit(lowered, results, forward_inputs)
    except ImportError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3
    except (ValueError, NotImplementedError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if len(outs) != 1:
        print(f"error: multi-output models not yet supported (got {len(outs)})", file=sys.stderr)
        return 2
    actual = outs[0].cpu().numpy()

    max_abs = float(np.abs(actual - ref).max())
    print(f"  out shape: {actual.shape}, max abs diff vs torch: {max_abs:.3e}")
    try:
        np.testing.assert_allclose(actual, ref, rtol=1e-3, atol=1e-4)
    except AssertionError as exc:
        print("FAIL")
        print(exc)
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
