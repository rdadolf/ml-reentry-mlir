"""Day-0 Task 1: characterize torch-mlir FX-importer sparsity behavior.

See internal-docs/short-term-tasks.md §Task 1 and the writeup in the
README.md alongside this script.

Traces three modules through torch_mlir.fx.export_and_import:

  c-matmul     dense @ dense (sanity baseline)
  a-gcn        one GCNConv layer — the "ingest PyG as-is" path
  b-sparse-mm  torch.matmul(csr, dense) with csr passed as input arg —
               the "name sparsity at the boundary" path

For each module, three IR stages are captured under dumps/:
  .1-raw-torch.mlir         post FX import
  .2-linalg.mlir            post torch-to-linalg-on-tensors backend pipeline
  .3-sparsifier.mlir        post mlir-opt --sparsifier
                            (or .3-*-error.txt if the stage fails)

Also captures b-sparse-mm.0-sparse-mm-rejected.mlir to document the
torch.sparse.mm dead-end vs. plain torch.matmul on sparse-typed operands.
"""

from __future__ import annotations

import os
import subprocess
import sys
import warnings
from pathlib import Path

import torch
import torch.nn as nn
from torch_geometric.nn import GCNConv
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


# ---------- Module C: dense @ dense (baseline) ----------
def trace_matmul() -> None:
    print("\n=== c-matmul: dense @ dense (baseline) ===")

    class MM(nn.Module):
        def forward(self, a: torch.Tensor, b: torch.Tensor) -> torch.Tensor:
            return a @ b

    a = torch.randn(3, 4)
    b = torch.randn(4, 2)
    module = export_and_import(MM().eval(), a, b)
    dump_stages("c-matmul", module)


# ---------- Module A: PyG GCNConv as-is ----------
def trace_gcn() -> None:
    print("\n=== a-gcn: PyG GCNConv single layer (as-is) ===")

    class GCN1(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            torch.manual_seed(0)
            self.conv = GCNConv(4, 2, add_self_loops=False, normalize=False, bias=False)

        def forward(self, x: torch.Tensor, edge_index: torch.Tensor) -> torch.Tensor:
            return self.conv(x, edge_index)

    m = GCN1().eval()
    x = torch.randn(3, 4)
    edge_index = torch.tensor([[0, 1, 0], [1, 2, 2]], dtype=torch.long)
    module = export_and_import(m, x, edge_index)
    dump_stages("a-gcn", module)


# ---------- Module B: torch.matmul(csr, dense), csr as input arg ----------
def trace_explicit_sparse() -> None:
    print("\n=== b-sparse-mm: torch.matmul(csr, dense), csr as arg ===")
    crow = torch.tensor([0, 1, 2, 3], dtype=torch.int64)
    col = torch.tensor([1, 2, 0], dtype=torch.int64)
    vals = torch.tensor([1.0, 1.0, 1.0])
    csr = torch.sparse_csr_tensor(crow, col, vals, size=(3, 3))
    dense = torch.randn(3, 4)

    # Dead-end variant: torch.sparse.mm. Captured for the writeup; not
    # routed through dump_stages because it is known to fail at the
    # torch-to-linalg lowering ("torch.aten._sparse_mm" extension op).
    class _SparseMM_dead(nn.Module):
        def forward(self, csr, dense):
            return torch.sparse.mm(csr, dense)

    rejected = export_and_import(_SparseMM_dead().eval(), csr, dense)
    (OUT / "b-sparse-mm.0-sparse-mm-rejected.mlir").write_text(str(rejected))
    print("  [b-sparse-mm] torch.sparse.mm path documented as dead-end:")
    print("                see b-sparse-mm.0-sparse-mm-rejected.mlir")

    # Working path: plain torch.matmul on sparse-typed operand.
    class Matmul(nn.Module):
        def forward(self, csr, dense):
            return torch.matmul(csr, dense)

    module = export_and_import(Matmul().eval(), csr, dense)
    dump_stages("b-sparse-mm", module)


def main() -> int:
    print(f"out dir: {OUT}")
    trace_matmul()
    trace_gcn()
    trace_explicit_sparse()
    print("\nDone. See", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
