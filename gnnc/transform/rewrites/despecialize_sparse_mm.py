"""Translate `aten._sparse_mm` to `torch.aten.mm`, as the former has no lowering.

Normally we'd just use `aten._sparse_mm` as the op root to match, but since it's
unregistered, we have to check manually.

Note that we intentionally do NOT match `_sparse_mm.reduce`, since that's not
semantically equivalent to a plain matmul.
"""

from __future__ import annotations

from torch_mlir.dialects import torch as torch_d


def _rewriter(op, rewriter) -> bool:
    from torch_mlir import ir

    if str(op.attributes["name"]).strip('"') != "torch.aten._sparse_mm":
        return True  # no match, try the next pattern

    with rewriter.ip:
        new = ir.Operation.create(
            "torch.aten.mm",
            results=[op.results[0].type],
            operands=list(op.operands),
            loc=op.location,
        )
    rewriter.replace_op(op, new)


despecialize_sparse_mm = (torch_d.OperatorOp, _rewriter)
