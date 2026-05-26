"""End-to-end smoke test for the Lighthouse integration.

Exercises the full Path-A wiring:

  1. co-load: `mlir` (our LLVM build) + `torch_mlir` (our build, NB-domain
     renamed) + `lighthouse` + `gnnc` in one process without the
     `PyGlobals already constructed` abort;
  2. recipe layer: `gnnc.recipes` resolves `cpu/passthrough` and Lighthouse
     flattens its `include:`d bundles;
  3. ingress + execution: a `torch.compile` matmul lowered through
     Lighthouse's `cpu_backend`, driven by our recipe via Lighthouse's
     `PipelineDriver`, JIT-executed, numerically checked against eager.

Runnable two ways:

  * `python test/integration/lighthouse_smoke.py`  → prints PASS/SKIP/FAIL,
    exit 0 on PASS or SKIP, non-zero on FAIL.
  * `pytest test/integration/lighthouse_smoke.py`  → skips (not fails) when
    the source-built stack / torch isn't importable.

SKIP (not FAIL) when the stack is absent so the check is safe to run in a
bare checkout or pre-commit without the multi-GB build present. Source
`tools/env.sh` (after building LLVM + torch-mlir) to make it run for real.
"""

from __future__ import annotations

import sys


class SmokeSkip(Exception):
    """Raised when prerequisites (built stack / torch) are unavailable."""


def _co_load():
    """Step 1: prove the SONAME collision is gone — co-load everything."""
    try:
        import lighthouse  # noqa: F401
        import mlir.ir  # noqa: F401
        import torch_mlir.fx  # noqa: F401

        import gnnc  # noqa: F401
    except ImportError as exc:
        raise SmokeSkip(f"stack not importable ({exc}); source tools/env.sh") from exc
    return lighthouse.__version__


def _recipe_layer():
    """Step 2: gnnc recipe resolves and Lighthouse flattens its includes."""
    from gnnc import recipes

    available = recipes.available()
    assert "cpu/passthrough" in available, available
    stages = recipes.load("cpu/passthrough")
    # 6 authored lines; the 3 include:d bundles expand to many more.
    assert len(stages) > 6, f"expected includes to flatten; got {len(stages)} stages"
    return available, len(stages)


def _end_to_end():
    """Step 3: torch.compile matmul lowered via our recipe + Lighthouse."""
    try:
        import torch
        import torch.nn as nn
    except ImportError as exc:
        raise SmokeSkip(f"torch not installed ({exc}); `uv sync`") from exc

    from lighthouse.pipeline.driver import PipelineDriver

    from gnnc import recipes
    from gnnc.ingress import TargetDialect, cpu_backend

    def lower(module):
        # Drive the cpu/passthrough recipe through Lighthouse's in-memory
        # pipeline driver — the real gnnc → Lighthouse path, not a
        # hand-rolled PassManager.
        driver = PipelineDriver(module.context)
        driver.add_stages(recipes.load("cpu/passthrough"))
        return driver.apply(module)

    @torch.compile(
        dynamic=False,
        backend=cpu_backend(lower, dialect=TargetDialect.LINALG_ON_TENSORS),
    )
    class M(nn.Module):
        def forward(self, a, b):
            return torch.matmul(a, b)

    a = torch.randn(4, 8)
    b = torch.randn(8, 2)
    out = M()(a, b)
    assert torch.allclose(a @ b, out, atol=1e-4), "compiled result diverged from eager"
    return tuple(out.shape)


def run() -> int:
    try:
        lh_version = _co_load()
        available, n_stages = _recipe_layer()
        shape = _end_to_end()
    except SmokeSkip as exc:
        print(f"SKIP: {exc}")
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"FAIL: {type(exc).__name__}: {exc}")
        return 1
    print(
        f"PASS: lighthouse {lh_version}; recipes {available}; "
        f"cpu/passthrough → {n_stages} stages; matmul out {shape}"
    )
    return 0


# --- pytest entry points (skip, not fail, when prerequisites are absent) ---


def _pytest_skip_or(fn):
    import pytest

    try:
        return fn()
    except SmokeSkip as exc:
        pytest.skip(str(exc))


def test_co_load():
    _pytest_skip_or(_co_load)


def test_recipe_layer():
    _pytest_skip_or(_co_load)
    _pytest_skip_or(_recipe_layer)


def test_end_to_end():
    _pytest_skip_or(_co_load)
    _pytest_skip_or(_end_to_end)


if __name__ == "__main__":
    sys.exit(run())
