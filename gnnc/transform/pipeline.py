"""Pre-legalization rewrite pipeline

torch-mlir has some gaps in lowering, but some can be fixed with simple rewrites
on the raw output, and this gives us a place to put them.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from gnnc.transform.rewrites.despecialize_sparse_mm import despecialize_sparse_mm

if TYPE_CHECKING:
    from torch_mlir.ir import Module


_rewrite_pipeline = [
    despecialize_sparse_mm,
]


def run(module: Module) -> Module:
    """Apply torch-dialect rewrites to `module`.

    Uses `walk_and_apply_patterns` (single walk, apply-once) rather than
    `apply_patterns_and_fold_greedily`: these are independent one-shot
    canonicalizations, and the greedy driver's folding fails to converge on the
    un-canonicalized torch-dialect IR. Switch to the greedy driver if a future
    rewrite needs fixed-point / cascading application.
    """
    from torch_mlir.rewrite import RewritePatternSet, walk_and_apply_patterns

    with module.context:
        patterns = RewritePatternSet(module.context)
        for root, fn in _rewrite_pipeline:
            patterns.add(root, fn)
        walk_and_apply_patterns(module.operation, patterns.freeze())
    return module
