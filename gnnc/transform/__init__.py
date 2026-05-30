"""Post-ingress torch-dialect rewrites (MLIR-level, on the in-memory module).

`run(module)` applies the ordered pipeline in `pipeline.py` via MLIR's
Python rewrite-pattern driver (`RewritePatternSet` +
`apply_patterns_and_fold_greedily`). Rewrites live in `rewrites/` as
`(root_op_type, fn)` pairs (the bindings' own pattern form); the pipeline
(policy) is just the ordered list. Distinct from the planned FX-level
`gnnc.ingress.pyg_rewrites`, which runs before torch-mlir import.
"""

from gnnc.transform.pipeline import run

__all__ = ["run"]
