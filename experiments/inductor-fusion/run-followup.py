"""Follow-up to run.py: how many Triton kernels does Inductor emit when
it receives the UNBROKEN FX graph?

The original run.py used the PyG default `add_self_loops=True`, which under
default `torch.compile` produces 3 FX subgraphs (the graph-break issue
characterized in experiments/dynamo-graph-breaks). Inductor was therefore
invoked separately on 3 disjoint subgraphs, and the kernel count it
produced conflated two distinct phenomena:

  1. Dynamo-level FX splitting (3 compile units)
  2. Inductor-level intra-graph kernel scheduling (kernels per unit)

This script measures (2) in isolation by passing Inductor a single
unbroken graph — either via `add_self_loops=False` on the conv
constructor (a model edit), or `fullgraph=True` on torch.compile (a
tracer config). Both produce 1 compile unit, isolating Inductor's
intra-graph fusion as the only remaining variable.

Two configurations, both with PyG helper libs masked (matches the
original `--disable-libs` mode so Inductor sees raw aten ops):

  A. single GATConv,  add_self_loops=False  (1 layer baseline)
  B. 2-layer GAT,     add_self_loops=False  (does Inductor fuse across layers?)

For each compile unit reported by `run_and_get_code`:
  - Count `@triton.jit` definitions (= Triton kernel launches)
  - Count `extern_kernels.foo(...)` calls (= cuBLAS / cuSPARSE launches)
  - List each kernel's "Topologically Sorted Source Nodes" annotation
    (= which GAT-pipeline source ops Inductor packed into that kernel)

Dumps go to `dumps/followup/` to avoid colliding with run.py's dumps/.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Mask helper libs at import time so Inductor sees ops directly.
for mod in ("torch_scatter", "torch_sparse", "pyg_lib"):
    sys.modules[mod] = None

import torch  # noqa: E402
import torch._dynamo as dynamo  # noqa: E402
import torch.nn.functional as F  # noqa: E402
from torch._inductor.utils import run_and_get_code  # noqa: E402
from torch_geometric.nn import GATConv  # noqa: E402


def make_inputs(nodes=100, edges=500, in_channels=16, device="cuda"):
    torch.manual_seed(0)
    x = torch.randn(nodes, in_channels, device=device)
    src = torch.randint(0, nodes, (edges,), device=device)
    dst = torch.randint(0, nodes, (edges,), device=device)
    return x, torch.stack([src, dst], dim=0)


class GAT2(torch.nn.Module):
    def __init__(self, in_c=16, hid=8, out_c=7, heads=8):
        super().__init__()
        self.conv1 = GATConv(in_c, hid, heads=heads, add_self_loops=False)
        self.conv2 = GATConv(hid * heads, out_c, heads=1, concat=False, add_self_loops=False)

    def forward(self, x, edge_index):
        x = self.conv1(x, edge_index)
        x = F.elu(x)
        return self.conv2(x, edge_index)


def analyse(name, fn, args, dump_dir, dump_prefix):
    dynamo.reset()
    compiled = torch.compile(fn, backend="inductor", fullgraph=True)
    with torch.no_grad():
        out, codes = run_and_get_code(compiled, *args)

    print()
    print("=" * 78)
    print(f"{name}: out.shape={tuple(out.shape)}, {len(codes)} compile unit(s)")
    print("=" * 78)

    for unit_i, code in enumerate(codes):
        kernel_blocks = re.findall(
            r"# Topologically Sorted Source Nodes: \[([^\]]+)\].*?"
            r"# Source node to ATen node mapping:\n",
            code,
            flags=re.S,
        )
        triton_defs = len(re.findall(r"^@triton\.jit", code, flags=re.M))
        extern_calls = re.findall(
            r"extern_kernels\.([a-zA-Z0-9_]+)\(",
            code,
        )
        body = code.split("def call(")[-1] if "def call(" in code else ""
        aten_extern = re.findall(
            r"torch\.ops\.aten\.([a-zA-Z0-9_]+)\.[a-zA-Z_]+\(",
            body,
        )

        print(f"\n  --- compile unit {unit_i} ---")
        print(f"  triton @jit kernels:        {triton_defs}")
        print(
            f"  extern_kernels.* calls:     {len(extern_calls)} "
            f"{sorted(set(extern_calls)) if extern_calls else ''}"
        )
        print(
            f"  torch.ops.aten.* in call(): {len(aten_extern)} "
            f"{sorted(set(aten_extern)) if aten_extern else ''}"
        )
        print("\n  Per-kernel source-op coverage:")
        for ki, ops in enumerate(kernel_blocks):
            ops_clean = ", ".join(o.strip() for o in ops.split(","))
            print(f"    kernel {ki}: {ops_clean}")

        # Dump the full generated code for offline inspection.
        out_file = dump_dir / f"{dump_prefix}.unit{unit_i}.py"
        out_file.write_text(code)

    return len(codes), sum(len(re.findall(r"^@triton\.jit", c, flags=re.M)) for c in codes)


def main():
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"torch={torch.__version__}  device={device}")

    dump_dir = Path(__file__).parent / "dumps" / "followup"
    dump_dir.mkdir(parents=True, exist_ok=True)

    x, ei = make_inputs(device=device)

    conv = GATConv(16, 8, heads=4, add_self_loops=False).to(device).eval()
    units1, kernels1 = analyse(
        "A. single GATConv, self_loops=False, fullgraph=True",
        lambda x, ei: conv(x, ei),
        (x, ei),
        dump_dir,
        "gatconv-1L-nolibs",
    )

    gat2 = GAT2(in_c=16, hid=8, out_c=7, heads=8).to(device).eval()
    units2, kernels2 = analyse(
        "B. 2-layer GAT, self_loops=False, fullgraph=True",
        lambda x, ei: gat2(x, ei),
        (x, ei),
        dump_dir,
        "gat2-nolibs",
    )

    print()
    print("=" * 78)
    print("Summary")
    print("=" * 78)
    print(f"1-layer GATConv: {units1} compile unit, {kernels1} Triton kernels")
    print(f"2-layer GAT:     {units2} compile unit, {kernels2} Triton kernels")
    if units1 == units2 == 1:
        ratio = kernels2 / kernels1 if kernels1 else float("nan")
        print(f"\n2-layer / 1-layer kernel ratio: {ratio:.2f}")
        if abs(ratio - 2.0) < 0.05:
            print("  => Inductor does ZERO cross-layer fusion (2× scaling is exact).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
