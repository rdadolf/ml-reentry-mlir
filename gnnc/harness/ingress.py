"""PyG → MLIR ingress.

Wraps torch-mlir's FX importer (`torch_mlir.fx.export_and_import`) and applies
any Python-level rewrites needed for the v0 path (sparse-encoding annotations
on linalg.generic). Real implementation lands in week 1.
"""

from __future__ import annotations


def import_pyg_model(*args, **kwargs):  # noqa: ARG001
    raise NotImplementedError("ingress.import_pyg_model lands in week 1")
