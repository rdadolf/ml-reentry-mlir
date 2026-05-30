"""Lower a (transformed) torch-dialect module to a backend dialect via torch-mlir.

Shared by `gnnc` (model -> MLIR) and `gnnc-opt` (MLIR -> MLIR). Expects the
module to be canonicalized first (`gnnc.transform`) — the torch-backend
legalization rejects un-rewritten ops like `torch.aten._sparse_mm`.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from torch_mlir.ir import Module


def lower(module: Module, dialect: str) -> Module:
    """Run torch-backend legalization, then lower to `dialect` in place.

    `dialect` is one of torch-mlir's `OutputType` names in CLI form:
    `torch` / `linalg-on-tensors` / `tosa` / `stablehlo`.
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
