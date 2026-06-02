"""Translate `aten._sparse_mm` to `torch.aten.mm`, as the former has no lowering.

Normally we'd just use `aten._sparse_mm` as the op root to match, but since it's
unregistered, we have to check manually.

The `.reduce` variant is *not* matched here — it carries a reduction kind and
isn't a plain matmul. See `despecialize_sparse_mm_reduce` for that.
"""

from __future__ import annotations

from torch_mlir.dialects import torch as torch_d


def _rewriter(op, rewriter) -> bool:
    if str(op.attributes["name"]).strip('"') != "torch.aten._sparse_mm":
        return True  # no match, try the next pattern

    A, X = op.operands
    with rewriter.ip, op.location:
        mm = torch_d.AtenMmOp(op.results[0].type, A, X).result
    rewriter.replace_op(op, [mm])


despecialize_sparse_mm = (torch_d.OperatorOp, _rewriter)
