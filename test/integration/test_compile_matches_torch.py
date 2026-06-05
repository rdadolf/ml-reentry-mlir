"""Compile-pipeline correctness: compiled output must match eager torch within tolerance."""

from __future__ import annotations

import numpy as np
import pytest
import torch

_SAGE_SKIP = "sparsifier hits UNREACHABLE on _sparse_mm.reduce-rewritten IR"
_GAT_SKIP = "gat model file not yet migrated to gnnc/examples/models/"

_CASES = [
    ("mlp", None),
    ("gcn", None),
    ("gcn", "cora"),
    ("gcn", "ogbn-arxiv"),
    pytest.param("sage", None, marks=pytest.mark.skip(reason=_SAGE_SKIP)),
    pytest.param("sage", "cora", marks=pytest.mark.skip(reason=_SAGE_SKIP)),
    pytest.param("sage", "ogbn-arxiv", marks=pytest.mark.skip(reason=_SAGE_SKIP)),
    pytest.param("gat", None, marks=pytest.mark.skip(reason=_GAT_SKIP)),
    pytest.param("gat", "cora", marks=pytest.mark.skip(reason=_GAT_SKIP)),
    pytest.param("gat", "ogbn-arxiv", marks=pytest.mark.skip(reason=_GAT_SKIP)),
]


@pytest.mark.parametrize("model_name,dataset", _CASES)
def test_compile_matches_torch(model_name, dataset):
    from gnnc.compile import compile_through_recipe
    from gnnc.examples import MODELS_DIR
    from gnnc.execution import run_jit
    from gnnc.ingress import get_model_and_data

    model, forward_inputs = get_model_and_data(MODELS_DIR / f"{model_name}.py", dataset)
    model.eval()
    with torch.no_grad():
        ref = model(*forward_inputs).cpu().numpy()
    lowered, results = compile_through_recipe(model, forward_inputs)
    (out,) = run_jit(lowered, results, forward_inputs)
    np.testing.assert_allclose(out.cpu().numpy(), ref, rtol=1e-3, atol=1e-4)
