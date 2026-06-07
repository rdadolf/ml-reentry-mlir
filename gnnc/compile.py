"""End-to-end compile pipeline: torch model → MLIR → recipe-lowered module.

Two granularities of entry point:

- `compile_to_dialect(model, inputs, dialect)` — composes ingress + transform
  + torch-mlir lowering. Returns a `torch_mlir.ir.Module` in the requested
  dialect. The right entry point for tools that want IR text (`gnnc`) or
  want to feed the result into a different driver.
- `compile_through_recipe(model, inputs, recipe)` — extends through the
  named recipe via Lighthouse's `PipelineDriver` / `MLIRBackend`,
  returning `(lowered_module, results)` ready for `gnnc.execution.run_jit`.

The individual phases (`run_transforms`, `lower`) are re-exposed for
`gnnc-opt`, which composes them per-flag rather than as a fixed pipeline.
"""

from __future__ import annotations

import functools
from typing import TYPE_CHECKING

from gnnc.conversion.tm_tensor_to_torch import run as run_transforms
from gnnc.ingress import import_as_raw_ir

if TYPE_CHECKING:
    import torch
    from mlir import ir as _ir
    from torch_mlir.ir import Module


__all__ = [
    "compile_through_recipe",
    "compile_to_dialect",
    "lower",
    "run_transforms",
]


def lower(module: Module, dialect: str) -> Module:
    """Run torch-backend legalization, then lower to `dialect` in place.

    `dialect` is one of torch-mlir's `OutputType` names in CLI form:
    `torch` / `linalg-on-tensors` / `tosa` / `stablehlo`. Expects the module
    to be canonicalized first (via `run_transforms`) — the torch-backend
    legalization rejects un-rewritten ops like `torch.aten._sparse_mm`.
    """
    from torch_mlir.compiler_utils import lower_mlir_module, run_pipeline_with_repro_report
    from torch_mlir.fx import OutputType

    run_pipeline_with_repro_report(
        module,
        "builtin.module(func.func(torch-match-quantized-custom-ops), "
        "torchdynamo-export-to-torch-backend-pipeline{ extra-library=})",
        "Lowering TorchFX IR -> Torch Backend IR",
    )
    lower_mlir_module(False, getattr(OutputType, dialect.replace("-", "_").upper()), module)
    return module


def compile_to_dialect(
    model: torch.nn.Module,
    forward_inputs: tuple,
    *,
    dialect: str = "linalg-on-tensors",
) -> Module:
    """Ingress → transform → lower; produce a torch-mlir `Module` in `dialect`.

    `dialect="raw"` short-circuits after ingress (no rewrites, no lowering).
    """
    module = import_as_raw_ir(model, forward_inputs)
    if dialect == "raw":
        return module
    run_transforms(module)
    lower(module, dialect)
    return module


def compile_through_recipe(
    model: torch.nn.Module,
    forward_inputs: tuple,
    *,
    recipe: str = "cpu/sparse-basic",
) -> tuple[_ir.Module, list]:
    """Compile `model` to a recipe-lowered (JIT-ready) MLIR module.

    Returns `(lowered, results)` where `lowered` is in Lighthouse's
    `mlir.ir.Context` and `results` is the entry function's result-type
    list, in the form `JITFunction(lowered, results, ...)` expects.

    We bypass `MLIRBackend.__call__` because it's gated on `torch.compile`,
    which Dynamo refuses for `torch.sparse_csr_tensor` inputs — ingress
    goes through `import_as_raw_ir` instead.
    """
    import torch
    from lighthouse.ingress.torch.compile import MLIRBackend
    from mlir import ir

    if recipe not in _RECIPE_KWARGS:
        raise NotImplementedError(f"unknown recipe {recipe!r}; known: {sorted(_RECIPE_KWARGS)}")

    module = compile_to_dialect(model, forward_inputs, dialect="linalg-on-tensors")
    text = str(module)

    # Round-trip into Lighthouse's MLIR context: torch_mlir's `ir.Context` is
    # a distinct Python type from `mlir.ir.Context` even though the underlying
    # C++ matches, and PassManager rejects the cross-binding context.
    ctx = _get_ir_context()
    with ctx, ir.Location.unknown():
        m = ir.Module.parse(text)
        backend = MLIRBackend(
            # Result buffers are allocated on the host regardless of target.
            # The gpu recipe emits implicit mgpuMemAlloc/Memcpy around the
            # kernel, so the host buffer we pass as a return arg is what the
            # kernel writes to after the device->host copy.
            device=torch.device("cpu"),
            fn_compile=lambda mod: _drive_recipe(mod, ctx, recipe),
            ir_context=ctx,
        )
        func_op = backend.get_entry_func(m)
        results = backend.get_results(func_op)
        # Move dense outputs into args (cribbed from MLIRBackend.preprocess_func)
        # but DO NOT privatize @main — `sparse-assembler` in the sparsifier
        # recipe only decomposes sparse-typed args on public (boundary) functions,
        # and privatizing here would silently turn that pass into a no-op.
        backend.move_results_to_args(func_op)
        lowered = backend.compile_mlir(m)
    return lowered, results


@functools.cache
def _get_ir_context() -> _ir.Context:
    """Process-wide singleton MLIR context with Lighthouse dialects loaded.

    Shared with `gnnc.execution.run_jit` (which calls back here). Memoized
    because `MLIRBackend` and downstream PassManagers assume a stable
    context across the compile+execute pair.
    """
    from lighthouse import dialects as lh_dialects
    from mlir import ir

    ctx = ir.Context()
    with ctx, ir.Location.unknown():
        lh_dialects.register_and_load()
    return ctx


_RECIPE_KWARGS = {
    "cpu/passthrough": {"target": "cpu", "has_sparse": False},
    "cpu/sparse-basic": {"target": "cpu", "has_sparse": True},
    "gpu/sparse-basic": {"target": "gpu", "has_sparse": True},
}


def _drive_recipe(module, ctx, recipe: str):
    """`fn_compile` callback for `MLIRBackend`: build and apply the named recipe."""
    from gnnc.schedule.sparse import build_pipeline

    return build_pipeline(ctx=ctx, **_RECIPE_KWARGS[recipe]).apply(module)
