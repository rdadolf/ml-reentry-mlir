"""Compile-pipeline correctness: compiled output must match eager torch within tolerance."""

from __future__ import annotations

import numpy as np
import pytest
import torch

_SAGE_SKIP = "sparsifier hits UNREACHABLE on _sparse_mm.reduce-rewritten IR"
_GAT_SKIP = "gat model file not yet migrated to gnnc/examples/models/"
# Upstream gpu-to-llvm bug: emits duplicate mgpuStreamSynchronize+Destroy on
# async-token fan-out (sparsifier always emits this pattern); first call to
# the destroyed handle segfaults libcuda. Local SSA-aware patch-up pass is
# being designed in gnnc/transform/; until it lands these segfault the test
# session. See internal-docs/upstream-gpu-to-llvm-stream-dedup.md for the bug.
_GPU_BUG_SKIP = "gpu-to-llvm stream double-destroy; local patch-up pass WIP"

_no_gpu = pytest.mark.skipif(not torch.cuda.is_available(), reason="no CUDA device available")
_gpu_bug = pytest.mark.skip(reason=_GPU_BUG_SKIP)

_CASES = [
    ("mlp", None, "cpu/sparse-basic"),
    ("gcn", None, "cpu/sparse-basic"),
    ("gcn", "cora", "cpu/sparse-basic"),
    ("gcn", "ogbn-arxiv", "cpu/sparse-basic"),
    pytest.param("mlp", None, "gpu/sparse-basic", marks=[_no_gpu, _gpu_bug]),
    pytest.param("gcn", None, "gpu/sparse-basic", marks=[_no_gpu, _gpu_bug]),
    pytest.param("gcn", "cora", "gpu/sparse-basic", marks=[_no_gpu, _gpu_bug]),
    pytest.param("gcn", "ogbn-arxiv", "gpu/sparse-basic", marks=[_no_gpu, _gpu_bug]),
    pytest.param("sage", None, "cpu/sparse-basic", marks=pytest.mark.skip(reason=_SAGE_SKIP)),
    pytest.param("sage", "cora", "cpu/sparse-basic", marks=pytest.mark.skip(reason=_SAGE_SKIP)),
    pytest.param(
        "sage", "ogbn-arxiv", "cpu/sparse-basic", marks=pytest.mark.skip(reason=_SAGE_SKIP)
    ),
    pytest.param("gat", None, "cpu/sparse-basic", marks=pytest.mark.skip(reason=_GAT_SKIP)),
    pytest.param("gat", "cora", "cpu/sparse-basic", marks=pytest.mark.skip(reason=_GAT_SKIP)),
    pytest.param("gat", "ogbn-arxiv", "cpu/sparse-basic", marks=pytest.mark.skip(reason=_GAT_SKIP)),
]


@pytest.mark.parametrize("model_name,dataset,recipe", _CASES)
def test_compile_matches_torch(model_name, dataset, recipe):
    from gnnc.compile import compile_through_recipe
    from gnnc.examples import MODELS_DIR
    from gnnc.execution import run_jit
    from gnnc.ingress import get_model_and_data

    model, forward_inputs = get_model_and_data(MODELS_DIR / f"{model_name}.py", dataset)
    model.eval()
    with torch.no_grad():
        ref = model(*forward_inputs).cpu().numpy()
    lowered, results = compile_through_recipe(model, forward_inputs, recipe=recipe)
    (out,) = run_jit(lowered, results, forward_inputs)
    np.testing.assert_allclose(out.cpu().numpy(), ref, rtol=1e-3, atol=1e-4)
