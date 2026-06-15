"""Assert that reshape ops preserve sparse encoding.

`tensor.expand_shape`, `tensor.collapse_shape`, and `tensor.reshape` re-index a
tensor's values across dimensions but don't change *which* values exist, so a
sparse-encoded input should generally produce a sparse-encoded output.

This is really a reaction to `linalg-fuse-elementwise-ops`, which drops
encodings when fusing linalg pairs whose iteration spaces don't align.
"""

from __future__ import annotations

from gnnc.passes._reg import gnnc_pass

_RESHAPE_OPS = frozenset(
    {
        "tensor.expand_shape",
        "tensor.collapse_shape",
        "tensor.reshape",
    }
)


@gnnc_pass(
    "gnnc-assert-reshape-encoding",
    summary="Error on a reshape-family op whose sparse-encoded input yields a dense output.",
)
def assert_reshape_preserves_encoding(op, pass_) -> None:
    from mlir.ir import RankedTensorType, WalkResult

    def encoding(t):
        return t.encoding if isinstance(t, RankedTensorType) else None

    failed = False

    def visit(inner):
        nonlocal failed
        if inner.name in _RESHAPE_OPS:
            in_type = inner.operands[0].type
            out_type = inner.results[0].type
            if encoding(in_type) is not None and encoding(out_type) is None:
                inner.location.emit_error(
                    f"{inner.name}: input is sparse-encoded but output is dense "
                    f"(in: {in_type}, out: {out_type})"
                )
                failed = True
        return WalkResult.ADVANCE

    op.walk(visit)
    if failed:
        pass_.signal_pass_failure()
