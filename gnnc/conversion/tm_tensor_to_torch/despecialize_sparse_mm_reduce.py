"""Translate `aten._sparse_mm.reduce` into `aten.mm` plus a row-nnz norm (as in GraphSAGE).

`_sparse_mm.reduce("mean")` computes `out[i,k] = (A @ X)[i,k] / nnz(A[i,:])`,
with empty rows (nnz=0) zeroes. We use `clamp_min(row_nnz, 1.0)` for that,
so the divide yields `0 / 1 = 0`.
"""

from __future__ import annotations

import torch
from torch_mlir import ir
from torch_mlir.dialects import torch as torch_d
from torch_mlir.extras.fx_importer import TORCH_DTYPE_TO_INT

from gnnc.conversion.tm_tensor_to_torch.util import TorchTensorTypeInfo, VTensor_get


def _rewriter(op, rewriter) -> bool:
    if str(op.attributes["name"]).strip('"') != "torch.aten._sparse_mm.reduce":
        return True  # no match, try the next pattern

    # We don't support non-"mean" reductions, and because this is the only
    # rewrite where `_sparse_mm.reduce` is handled, any failure is fatal.
    reduce_op = op.operands[2].owner
    reduce_kind = str(reduce_op.attributes["value"]).strip('"')
    if reduce_kind != "mean":
        op.location.emit_error(
            f"gnnc: _sparse_mm.reduce with reduce='{reduce_kind}' not yet supported (only 'mean')"
        )
        return True

    A, X, _ = op.operands
    out_type = op.results[0].type
    ctx = op.context

    # Intermediate result types derived from the rewrite's inputs.
    A_info = TorchTensorTypeInfo.from_type(A.type)
    i1_type = ir.Type.parse("i1", ctx)
    a_i1_type = VTensor_get(
        shape=A_info.shape,
        element_type=i1_type,
        encoding=A_info.encoding,
        context=ctx,
    )

    out_info = TorchTensorTypeInfo.from_type(out_type)
    if not out_info.has_rank or out_info.is_dynamic_dim(0):
        return True  # dynamic leading dim unsupported
    N = out_info.get_dim_size(0)
    f32_type = ir.Type.parse("f32", ctx)
    row_nnz_type = VTensor_get(shape=(N,), element_type=f32_type, context=ctx)
    divisor_type = VTensor_get(shape=(N, 1), element_type=f32_type, context=ctx)
    list_int_type = ir.Type.parse("!torch.list<int>", ctx)

    with rewriter.ip, op.location:
        c_i0 = torch_d.ConstantIntOp(0).result
        c_i1 = torch_d.ConstantIntOp(1).result
        c_f32_dtype = torch_d.ConstantIntOp(TORCH_DTYPE_TO_INT[torch.float32]).result
        c_f1 = torch_d.ConstantFloatOp(1.0).result
        c_false = torch_d.ConstantBoolOp(False).result
        c_none = torch_d.ConstantNoneOp().result

        # mm      = aten.mm(A, X)
        mm = torch_d.AtenMmOp(out_type, A, X).result
        # row_nnz = aten.sum((A != 0).to(f32), dim=1)
        nz_mask = torch_d.AtenNeScalarOp(a_i1_type, A, c_i0).result
        nz_f32 = torch_d.PrimsConvertElementTypeOp(A.type, nz_mask, c_f32_dtype).result
        dims = torch_d.PrimListConstructOp(list_int_type, [c_i1]).result
        row_nnz = torch_d.AtenSumDimIntListOp(row_nnz_type, nz_f32, dims, c_false, c_none).result
        # out     = mm / clamp_min(row_nnz, 1.0).unsqueeze(1)
        row_nnz_safe = torch_d.AtenClampMinOp(row_nnz_type, row_nnz, c_f1).result
        divisor = torch_d.AtenUnsqueezeOp(divisor_type, row_nnz_safe, c_i1).result
        out = torch_d.AtenDivTensorOp(out_type, mm, divisor).result

    rewriter.replace_op(op, [out])


despecialize_sparse_mm_reduce = (torch_d.OperatorOp, _rewriter)
