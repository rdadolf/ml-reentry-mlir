"""GATConv FX characterization. See README.md alongside this script.

Trace a single real PyG GATConv layer (small synthetic graph, no training)
through torch_mlir.fx.export_and_import and dump three IR stages:

  gat.1-raw-torch.mlir       post FX import
  gat.2-linalg.mlir          post torch-to-linalg backend pipeline
  gat.3-sparsifier.mlir      post mlir-opt --sparsifier
                             (or gat.3-sparsifier-error.txt if the stage fails)

Goal: locate the attention-coefficient SDDMM, the edge-softmax (segmented
reduction by destination node), and the weighted aggregation in the lowered
IR, and record the adapter-need verdict that drives the downstream GAT
ingress rewrite.

Structure mirrors experiments/fx-sparsity/run.py — the run_pass /
dump_stages helpers are reused near-verbatim.
"""

from __future__ import annotations

import os
import subprocess
import sys
import warnings
from pathlib import Path

import torch
import torch.nn as nn
from torch_geometric.nn import GATConv
from torch_mlir.fx import export_and_import

warnings.filterwarnings("ignore")

LLVM_BUILD = os.environ.get("LLVM_BUILD", "/x/cache/build/llvm")
TORCH_MLIR_BUILD = os.environ.get("TORCH_MLIR_BUILD", "/x/cache/build/torch-mlir")
MLIR_OPT = f"{LLVM_BUILD}/bin/mlir-opt"
TORCH_MLIR_OPT = f"{TORCH_MLIR_BUILD}/bin/torch-mlir-opt"

OUT = Path(__file__).parent / "dumps"
OUT.mkdir(exist_ok=True)


def run_pass(input_mlir: str, args: list[str], tool: str = TORCH_MLIR_OPT) -> tuple[str, str]:
    """Pipe IR through a tool with given args. Returns (stdout, stderr)."""
    p = subprocess.run(
        [tool, *args],
        input=input_mlir,
        capture_output=True,
        text=True,
        check=False,
    )
    return p.stdout, p.stderr


def dump_stages(name: str, module) -> None:
    """Dump three stages of IR for a torch-mlir-imported module."""
    raw = str(module)
    (OUT / f"{name}.1-raw-torch.mlir").write_text(raw)
    print(f"  [{name}] raw torch:       {len(raw.splitlines()):4d} lines")

    stage2, err2 = run_pass(
        raw,
        [
            "--torch-function-to-torch-backend-pipeline",
            "--torch-backend-to-linalg-on-tensors-backend-pipeline",
        ],
    )
    if not stage2:
        (OUT / f"{name}.2-linalg-error.txt").write_text(err2)
        first = err2.splitlines()[0] if err2 else "(empty stderr)"
        print(f"  [{name}] linalg lower:    FAILED — {first}")
        return
    (OUT / f"{name}.2-linalg.mlir").write_text(stage2)
    print(f"  [{name}] post-linalg:     {len(stage2.splitlines()):4d} lines")

    stage3, err3 = run_pass(stage2, ["--sparsifier"], tool=MLIR_OPT)
    if not stage3:
        (OUT / f"{name}.3-sparsifier-error.txt").write_text(err3)
        first = err3.splitlines()[0] if err3 else "(empty stderr)"
        print(f"  [{name}] sparsifier:      FAILED — {first}")
        return
    (OUT / f"{name}.3-sparsifier.mlir").write_text(stage3)
    print(f"  [{name}] post-sparsifier: {len(stage3.splitlines()):4d} lines")


def trace_gat() -> None:
    """Trace one PyG GATConv layer with a small synthetic graph.

    GATConv config picked for IR clarity, not realism: small in/out, two heads
    (enough to expose the multi-head dimension), concat=True so the heads axis
    stays explicit through the output, and add_self_loops/bias disabled so the
    IR focuses on the attention + message-pass core rather than bookkeeping.
    """
    print("\n=== gat: PyG GATConv single layer ===")

    class GAT1(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            torch.manual_seed(0)
            self.conv = GATConv(
                in_channels=4,
                out_channels=2,
                heads=2,
                concat=True,
                add_self_loops=False,
                bias=False,
            )

        def forward(self, x: torch.Tensor, edge_index: torch.Tensor) -> torch.Tensor:
            return self.conv(x, edge_index)

    m = GAT1().eval()
    # Same shape as fx-sparsity/a-gcn for direct comparability:
    # 3 nodes, 3 edges (0->1, 1->2, 0->2).
    x = torch.randn(3, 4)
    edge_index = torch.tensor([[0, 1, 0], [1, 2, 2]], dtype=torch.long)
    module = export_and_import(m, x, edge_index)
    dump_stages("gat", module)


def main() -> int:
    print(f"out dir: {OUT}")
    trace_gat()
    print("\nDone. See", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
