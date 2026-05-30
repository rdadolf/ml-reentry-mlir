"""gnnc-bench correctness: compiled output must match the known-good golden.

Parametrized over every (model, dataset). These xfail until gnnc-bench's
compile+execute path (`gnnc.tools.gnnc_bench.evaluate`) is implemented; once
it is, they become the real correctness gate. lit covers IR *shape*; this
covers the *numbers*, which FileCheck can't.

Note on current goldens: the GCN goldens were regenerated against the current
model; SAGE/GAT goldens predate the migrated models (and GAT isn't migrated
yet), so when `evaluate` lands, those two will fail (not xpass) until their
goldens are regenerated — which is the correct signal.
"""

from __future__ import annotations

from itertools import product

import pytest

from gnnc.paths import GOLDENS_DIR

_MODELS = ("gcn", "sage", "gat")
_DATASETS = ("cora", "ogbn-arxiv")


@pytest.mark.parametrize("model,dataset", list(product(_MODELS, _DATASETS)))
@pytest.mark.xfail(
    reason="gnnc-bench compile+execute (gnnc.tools.gnnc_bench.evaluate) not implemented",
    raises=NotImplementedError,
    strict=False,
)
def test_bench_output_matches_golden(model, dataset):
    from gnnc.harness.compare import compare
    from gnnc.tools.gnnc_bench import evaluate

    actual = evaluate(model, dataset)  # xfails here (NotImplementedError) until implemented
    compare(actual, GOLDENS_DIR / f"{model}_{dataset}.npy")
