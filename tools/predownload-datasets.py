#!/usr/bin/env python3
"""Predownload Cora and OGB-arxiv to GNNC_DATA_DIR.

Skips OGB-products (1.5 GB; stretch goal, downloaded explicitly later).
Idempotent: existing dataset directories are reused.

Run after `uv sync --extra ingress-cuda --extra dev` (or the cpu variant).
"""

from __future__ import annotations

import sys

from gnnc.paths import DATA_DIR


def _download_cora() -> None:
    from torch_geometric.datasets import Planetoid

    root = DATA_DIR / "planetoid"
    root.mkdir(parents=True, exist_ok=True)
    print(f"Downloading Cora to {root} ...")
    ds = Planetoid(root=str(root), name="Cora")
    data = ds[0]
    print(
        f"  Cora: {data.num_nodes} nodes, {data.num_edges} edges, "
        f"{ds.num_node_features} features, {ds.num_classes} classes"
    )


def _download_ogbn_arxiv() -> None:
    from ogb.nodeproppred import PygNodePropPredDataset

    root = DATA_DIR / "ogb"
    root.mkdir(parents=True, exist_ok=True)
    print(f"Downloading ogbn-arxiv to {root} ...")
    ds = PygNodePropPredDataset(name="ogbn-arxiv", root=str(root))
    data = ds[0]
    print(
        f"  ogbn-arxiv: {data.num_nodes} nodes, {data.num_edges} edges, "
        f"{ds.num_features} features, {ds.num_classes} classes"
    )


def main() -> int:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    print(f"GNNC_DATA_DIR = {DATA_DIR}")
    _download_cora()
    _download_ogbn_arxiv()
    print("\nDone. To pull ogbn-products (1.5 GB) later:")
    print(
        '  python -c "from ogb.nodeproppred import PygNodePropPredDataset; '
        "from gnnc.paths import DATA_DIR; "
        "PygNodePropPredDataset(name='ogbn-products', root=str(DATA_DIR / 'ogb'))\""
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
