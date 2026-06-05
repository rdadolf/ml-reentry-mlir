"""From user-land Python to raw torch-dialect MLIR.

Covers two adjacent jobs:

  - building a `(model, forward_inputs)` pair from a model file (with
    optional named-dataset input sourcing), and
  - running that pair through `torch.export` / `torch_mlir.fx.export_and_import`
    to produce a raw torch-dialect MLIR module.
"""

from __future__ import annotations

import importlib.util
import warnings
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import torch
    from torch_mlir.ir import Module

_DEFAULT_HIDDEN = 64


def get_model_and_data(
    model_file: Path, dataset: str | None = None
) -> tuple[torch.nn.Module, tuple]:
    """Load `model_file` once, build forward inputs, and construct the model.

    With `dataset=None`, inputs come from the file's own `get_inputs()` and
    `get_init_inputs()` (KernelBench-style synthetic). With a named dataset,
    inputs are `(x, normalized_csr_adj)` from disk and the constructor dims
    are derived from the dataset's feature / class counts so the model fits
    the real-data shape.
    """
    import torch

    spec = importlib.util.spec_from_file_location("_gnnc_model", str(model_file))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    if dataset is None:
        forward_inputs = module.get_inputs()
        init_inputs = module.get_init_inputs()
    else:
        forward_inputs, init_inputs = _dataset_inputs(dataset)

    torch.manual_seed(0)
    return module.Model(*init_inputs), forward_inputs


def _dataset_inputs(dataset: str) -> tuple[tuple, tuple]:
    """Load a named dataset; return `(forward_inputs, init_inputs)`."""
    from gnnc.examples.util import normalized_csr_adj
    from gnnc.paths import DATA_DIR

    if dataset == "cora":
        from torch_geometric.datasets import Planetoid

        ds = Planetoid(root=str(DATA_DIR / "planetoid"), name="Cora")
    elif dataset == "ogbn-arxiv":
        # OGB's `outdated` PyPI check imports the deprecated pkg_resources and
        # emits noisy warnings; stub it out before the ogb import.
        import sys
        import types

        sys.modules.setdefault("outdated", types.ModuleType("outdated"))
        import torch
        from ogb.nodeproppred import PygNodePropPredDataset
        from torch_geometric.data.data import DataEdgeAttr, DataTensorAttr
        from torch_geometric.data.storage import GlobalStorage

        # OGB calls `torch.load` without overriding `weights_only`; torch 2.6
        # flipped that default to True, so we have to allowlist the PyG
        # metadata classes embedded in the pickled `Data` object.
        with torch.serialization.safe_globals([DataEdgeAttr, DataTensorAttr, GlobalStorage]):
            ds = PygNodePropPredDataset(name="ogbn-arxiv", root=str(DATA_DIR / "ogb"))
    else:
        raise ValueError(f"unknown dataset: {dataset}")

    data = ds[0]
    adj = normalized_csr_adj(data.edge_index, data.num_nodes)
    return (data.x, adj), (ds.num_node_features, _DEFAULT_HIDDEN, ds.num_classes)


def import_as_raw_ir(model: torch.nn.Module, forward_inputs: tuple) -> Module:
    """Import `model` as a raw torch-dialect MLIR module via torch.export.

    Uses `torch_mlir.fx.export_and_import` rather than `torch.compile` /
    Lighthouse's `MLIRBackend` because Dynamo refuses `torch.sparse_csr_tensor`
    inputs, and `torch.export` preserves the sparse tensor encoding which the
    sparsifier downstream needs to see.
    """
    from torch_mlir.fx import OutputType, export_and_import

    model.eval()
    with warnings.catch_warnings():
        # torch.export's pytree emits a FutureWarning about LeafSpec from
        # torch internals — unactionable here, so scope it out around the
        # export only.
        warnings.filterwarnings("ignore", message=r".*LeafSpec.*", category=FutureWarning)
        return export_and_import(model, *forward_inputs, output_type=OutputType.RAW)
