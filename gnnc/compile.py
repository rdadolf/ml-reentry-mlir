"""End-to-end compile pipeline: torch model → MLIR → fully-lowered module.

Two entry points:

- `lower(model, inputs, ...)` runs the phase pipeline (ingress → torch rewrites →
  legalize → linalg → the Lighthouse sparse schedule), halting where asked, and
  returns `(module, trace)`. For tools that want IR text (`gnnc-import`).
- `compile_executable(model, inputs, target=...)` extends through
  the schedule via `MLIRBackend`, returning `(lowered, results)` ready for
  `gnnc.execution.run_jit`.

The frontend phases run in torch-mlir's context; a `reimport` phase round-trips
the IR as text into Lighthouse's context, where the schedule phases run — the two
are separate MLIR builds, so text is the only bridge.
"""

from __future__ import annotations

import functools
import re
from typing import TYPE_CHECKING

from gnnc import get_context
from gnnc.conversion.tm_tensor_to_torch import rewrite_names
from gnnc.conversion.tm_tensor_to_torch import run as run_transforms
from gnnc.ingress import import_as_raw_ir
from gnnc.pipeline.phase import PhasePipeline
from gnnc.schedule.sparse import build_pipeline

if TYPE_CHECKING:
    import torch
    from mlir import ir as _ir
    from torch_mlir.ir import Module


__all__ = [
    "compile_executable",
    "lower",
]


# The torch-backend legalization. The IR after it is the `torch` dialect backend
# contract — i.e. what `--stop-after torch-legalize` emits.
_TORCH_BACKEND_PIPELINE = (
    "builtin.module(func.func(torch-match-quantized-custom-ops), "
    "torchdynamo-export-to-torch-backend-pipeline{ extra-library=})"
)


def _torch_legalize(module: Module) -> Module:
    """Run torch-backend legalization in place; leaves the module at the
    `OutputType.TORCH` backend contract. Expects `run_transforms` to have run
    first — legalization rejects un-rewritten ops like `torch.aten._sparse_mm`."""
    from torch_mlir.compiler_utils import run_pipeline_with_repro_report

    run_pipeline_with_repro_report(
        module, _TORCH_BACKEND_PIPELINE, "Lowering TorchFX IR -> Torch Backend IR"
    )
    return module


def _lower_to_linalg(module: Module) -> Module:
    """Lower a torch-backend-contract module to linalg-on-tensors in place."""
    from torch_mlir.compiler_utils import lower_mlir_module
    from torch_mlir.fx import OutputType

    lower_mlir_module(False, OutputType.LINALG_ON_TENSORS, module)
    return module


@functools.cache
def _expand_pipeline(pipeline: str) -> tuple[str, ...]:
    """The passes `pipeline` expands to, for the `--trace` listing."""
    from torch_mlir import ir
    from torch_mlir.dialects import torch  # noqa: F401 — registers the passes
    from torch_mlir.passmanager import PassManager

    # Parsing runs the pipeline's builder, so its printed form names the real
    # constituent passes: `builtin.module(passA, func.func(passB){opts}, …)`. Take
    # the top-level comma list (commas inside (…) or {…} don't count) and drop the
    # option groups.
    printed = str(PassManager.parse(pipeline, ir.Context()))
    body = printed[printed.index("(") + 1 : printed.rindex(")")]
    passes, nesting, split_at = [], 0, 0
    for pos, char in enumerate(body):
        if char in "({":
            nesting += 1
        elif char in ")}":
            nesting -= 1
        elif char == "," and nesting == 0:
            passes.append(body[split_at:pos])
            split_at = pos + 1
    passes.append(body[split_at:])
    return tuple(re.sub(r"\{[^{}]*\}", "", p).strip() for p in passes)


def _reimport(module):
    """Convert to text IR and back.

    This is because the context from torch-mlir is distinct from MLIR from lighthouse."""
    from mlir import ir

    text = str(module)
    ctx = get_context()
    with ctx, ir.Location.unknown():
        return ir.Module.parse(text)


def _frontend_pipeline(model: torch.nn.Module, forward_inputs: tuple) -> PhasePipeline:
    """Import from torch and lower all the way to linalg."""
    pipeline = PhasePipeline()
    pipeline.add_callable_phase(
        "import", lambda _: import_as_raw_ir(model, forward_inputs), ("torch.export FX import",)
    )
    pipeline.add_callable_phase("torch-rewrite", run_transforms, rewrite_names)
    pipeline.add_callable_phase(
        "torch-legalize", _torch_legalize, _expand_pipeline(_TORCH_BACKEND_PIPELINE)
    )
    pipeline.add_callable_phase(
        "linalg-lower",
        _lower_to_linalg,
        _expand_pipeline("builtin.module(torch-backend-to-linalg-on-tensors-backend-pipeline)"),
    )
    return pipeline


def lower(
    model: torch.nn.Module,
    forward_inputs: tuple,
    *,
    target: str = "cpu",
    stop_before: str | None = None,
    stop_after: str | None = None,
    print_ir_before: frozenset[str] = frozenset(),
    print_ir_after: frozenset[str] = frozenset(),
    emit=print,
) -> tuple[object, list[tuple[str, tuple[str, ...]]]]:
    """Run the phase pipeline, halting per `stop_*`. Returns `(module, trace)`.

    With no `stop_*` it runs to the end (a fully lowered LLVM-dialect module in
    Lighthouse's context). `emit` receives `--print-ir-*` dumps."""
    # frontend (torch-mlir) → reimport handoff → the Lighthouse schedule.
    pipeline = _frontend_pipeline(model, forward_inputs)
    pipeline.add_callable_phase("reimport", _reimport)
    pipeline.extend(build_pipeline(target=target))
    return pipeline.run(
        None,
        get_context,
        stop_before=stop_before,
        stop_after=stop_after,
        print_ir_before=print_ir_before,
        print_ir_after=print_ir_after,
        emit=emit,
    )


def compile_executable(
    model: torch.nn.Module,
    forward_inputs: tuple,
    *,
    target: str = "cpu",
) -> tuple[_ir.Module, list]:
    """Compile `model` to a JIT-ready MLIR module.

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

    # Run the frontend only (through linalg); the schedule runs below via
    # MLIRBackend, which needs its own ABI prep around it.
    module, _ = _frontend_pipeline(model, forward_inputs).run(
        None, get_context, stop_after="linalg-lower"
    )
    text = str(module)

    ctx = get_context()
    with ctx, ir.Location.unknown():
        m = ir.Module.parse(text)

        def run_schedule(mod):
            return build_pipeline(target=target).run(mod, lambda: ctx)[0]

        backend = MLIRBackend(
            # Result buffers are allocated on the host regardless of target.
            # The gpu schedule emits implicit mgpuMemAlloc/Memcpy around the
            # kernel, so the host buffer we pass as a return arg is what the
            # kernel writes to after the device->host copy.
            device=torch.device("cpu"),
            fn_compile=run_schedule,
            ir_context=ctx,
        )
        func_op = backend.get_entry_func(m)
        results = backend.get_results(func_op)
        # Move dense outputs into args (cribbed from MLIRBackend.preprocess_func)
        # but DO NOT privatize @main — `sparse-assembler` only decomposes
        # sparse-typed args on public (boundary) functions, and privatizing here
        # would silently turn that pass into a no-op.
        backend.move_results_to_args(func_op)
        lowered = backend.compile_mlir(m)
    return lowered, results
