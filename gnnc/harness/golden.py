"""Golden-output generation.

Loads a reference PyG model on the given dataset, runs a deterministic CPU
forward pass, and persists the output as a numpy array under
GNNC_DATA_DIR/goldens/.

CLI:
    python -m gnnc.harness.golden --model gcn --dataset cora
"""

from __future__ import annotations

import argparse
import sys

import numpy as np
import torch

from gnnc.harness.compare import save_golden
from gnnc.paths import DATA_DIR, GOLDENS_DIR


def _load_dataset(name: str):
    if name == "cora":
        from torch_geometric.datasets import Planetoid

        ds = Planetoid(root=str(DATA_DIR / "planetoid"), name="Cora")
        return ds[0], ds.num_node_features, ds.num_classes
    if name == "ogbn-arxiv":
        from ogb.nodeproppred import PygNodePropPredDataset

        ds = PygNodePropPredDataset(name="ogbn-arxiv", root=str(DATA_DIR / "ogb"))
        data = ds[0]
        return data, data.num_features, ds.num_classes
    raise ValueError(f"unknown dataset: {name}")


def _make_model(name: str, in_channels: int, out_channels: int):
    if name == "gcn":
        from examples.models.gcn import make

        return make(in_channels, out_channels)
    if name == "sage":
        from examples.models.sage import make

        return make(in_channels, out_channels)
    if name == "gat":
        from examples.models.gat import make

        return make(in_channels, out_channels)
    raise ValueError(f"unknown model: {name}")


def generate(model_name: str, dataset_name: str) -> np.ndarray:
    torch.manual_seed(0)
    data, in_ch, out_ch = _load_dataset(dataset_name)
    model = _make_model(model_name, in_ch, out_ch)
    model.eval()
    with torch.no_grad():
        out = model(data.x, data.edge_index)
    out_np = out.cpu().numpy()
    save_golden(out_np, GOLDENS_DIR / f"{model_name}_{dataset_name}.npy")
    return out_np


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, choices=["gcn", "sage", "gat"])
    parser.add_argument("--dataset", required=True, choices=["cora", "ogbn-arxiv"])
    args = parser.parse_args(argv)
    out = generate(args.model, args.dataset)
    print(f"golden written: {GOLDENS_DIR / f'{args.model}_{args.dataset}.npy'}")
    print(
        f"  shape={out.shape}, dtype={out.dtype}, "
        f"min={out.min():.4f}, max={out.max():.4f}, mean={out.mean():.4f}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
