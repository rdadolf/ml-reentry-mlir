"""execution — JIT execution of a recipe-lowered MLIR module.

`run_jit(lowered, results, inputs)` is gnnc's JIT entry point: it builds a
Lighthouse `JITFunction` over the lowered module, decomposes sparse tensor
inputs into the component memrefs the `sparse-assembler` boundary expects,
and invokes the call.

Also re-exports Lighthouse's `Runner` / `MemoryManager` for callers that
need the lower-level execution surface.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

__all__ = ["GPUMemoryManager", "MemoryManager", "Runner", "run_jit"]

if TYPE_CHECKING:
    import torch
    from lighthouse.execution import GPUMemoryManager, MemoryManager  # noqa: F401
    from lighthouse.execution.runner import Runner  # noqa: F401
    from mlir import ir as _ir


def run_jit(lowered: _ir.Module, results: list, inputs: tuple) -> list[torch.Tensor]:
    """JIT-compile and invoke `lowered`, returning the entry function's outputs.

    `lowered` and `results` are what `gnnc.compile.compile_through_recipe`
    returns. `inputs` is the same `forward_inputs` tuple passed to compile;
    sparse-CSR layouts are decomposed here into the component dense tensors
    that `sparse-assembler` exposes at the function boundary.
    """
    from lighthouse.ingress.torch.compile import JITFunction
    from mlir import ir

    from gnnc.compile import _get_ir_context

    ctx = _get_ir_context()
    with ctx, ir.Location.unknown():
        jit = JITFunction(lowered, results)
        return jit(*_decompose_sparse(inputs))


def _decompose_sparse(args):
    """Flatten a tuple of input tensors, expanding sparse layouts into the
    component dense tensors that `sparse-assembler` exposes at the function
    boundary. CSR yields (crow_indices, col_indices, values) in that order;
    strided tensors pass through. Mirrors MPACT's `mpact_jit_run`.

    All yielded tensors are forced contiguous: Lighthouse's `to_memref`
    uses `data_ptr()` and assumes contiguous storage. Some real datasets
    (OGB's `data.x`) return non-contiguous views, which would silently
    produce a memref whose strides don't match the actual layout.
    """
    import torch

    out = []
    for t in args:
        t = t.detach()
        if t.layout == torch.strided:
            out.append(t.contiguous())
        elif t.layout == torch.sparse_csr:
            out.extend(
                [
                    t.crow_indices().contiguous(),
                    t.col_indices().contiguous(),
                    t.values().contiguous(),
                ]
            )
        else:
            raise NotImplementedError(f"unsupported tensor layout: {t.layout}")
    return out


def __getattr__(name: str):
    if name == "Runner":
        from lighthouse.execution.runner import Runner

        return Runner
    if name in ("MemoryManager", "GPUMemoryManager"):
        import lighthouse.execution as _le

        return getattr(_le, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
