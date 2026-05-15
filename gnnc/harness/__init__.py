"""harness — GNN-specific correctness tooling.

After the Lighthouse integration, the generic driver layer (ingress,
recipes/pipeline, execution) is provided by Lighthouse and re-exported from
`gnnc.ingress` / `gnnc.recipes` / `gnnc.execution`. What remains here is the
part Lighthouse has no equivalent for: golden-output generation against the
PyG reference path (`golden.py`) and tolerance-aware comparison
(`compare.py`).
"""
