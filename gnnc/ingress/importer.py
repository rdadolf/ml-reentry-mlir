"""PyG -> MLIR ingress (export path).

Uses `torch.export` via `torch_mlir.fx.export_and_import` directly (NOT
`torch.compile` / Lighthouse's `MLIRBackend`): Dynamo refuses
`torch.sparse_csr_tensor` inputs, whereas `torch.export` preserves
`#sparse_tensor.encoding` on the MLIR function signature.

Ingress always produces the **raw** torch-dialect import (`OutputType.RAW`).
Stock PyG convs fed a sparse_csr adjacency emit `torch.aten._sparse_mm` here —
an unregistered `torch.operator`. `gnnc.transform` canonicalizes it; downstream
lowering lives in `gnnc.lowering`. The CLI composes ingress + transform + lowering.

  import_model_module(path) -> in-memory torch_mlir.ir.Module (raw)
"""

from __future__ import annotations

import importlib.util
import warnings
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from torch_mlir.ir import Module


def _load_model_file(path: str | Path, *, model_init_args=None, sample_args=None):
    """Load a KernelBench-style model file (`Model` + `get_init_inputs` +
    `get_inputs`) and return `(model, sample_args)`. `model_init_args` /
    `sample_args` override the file's toy defaults (for real-dataset dims)."""
    spec = importlib.util.spec_from_file_location("_gnnc_model", str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    init_args = model_init_args if model_init_args is not None else module.get_init_inputs()
    sargs = sample_args if sample_args is not None else module.get_inputs()
    return module.Model(*init_args), sargs


def import_model_module(path: str | Path, *, model_init_args=None, sample_args=None) -> Module:
    """File -> in-memory raw torch-dialect `torch_mlir.ir.Module`."""
    from torch_mlir.fx import OutputType, export_and_import

    model, sargs = _load_model_file(path, model_init_args=model_init_args, sample_args=sample_args)
    model.eval()
    with warnings.catch_warnings():
        # torch.export's pytree emits a FutureWarning about LeafSpec from torch
        # internals -- unactionable here, so scope it out around the export only.
        warnings.filterwarnings("ignore", message=r".*LeafSpec.*", category=FutureWarning)
        return export_and_import(model, *sargs, output_type=OutputType.RAW)
