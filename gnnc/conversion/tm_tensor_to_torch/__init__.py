"""tm_tensor to torch patch-up conversion.

torch-mlir has some gaps in lowering tm_tensor to torch, and it can leave
illegal ops in the output, causing further lowering to fail. Luckily, we can
pretty much patch this over with simple rewrites on the raw output of torch-mlir
without need for upstream surgery.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from gnnc.conversion.tm_tensor_to_torch.despecialize_sparse_mm import despecialize_sparse_mm
from gnnc.conversion.tm_tensor_to_torch.despecialize_sparse_mm_reduce import (
    despecialize_sparse_mm_reduce,
)

if TYPE_CHECKING:
    from torch_mlir.ir import Module


__all__ = ["run"]


_conversion_pipeline = [
    despecialize_sparse_mm,
    despecialize_sparse_mm_reduce,
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
        for root, fn in _conversion_pipeline:
            patterns.add(root, fn)
        walk_and_apply_patterns(module.operation, patterns.freeze())
    return module
