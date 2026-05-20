"""How many distinct Triton kernels does Inductor emit for a single GATConv
forward pass? Settles the claim that Inductor cannot fuse across the
SDDMM → segment-softmax → SpMM-with-weighted-messages pipeline.

Verdict logic:
- 1 kernel  -> hypothesis wrong, Inductor fused the whole pipeline
- 2 kernels -> partial fusion (interesting)
- 3+ kernels -> hypothesis confirmed, Inductor treats each stage as a
                separate launch (with possibly extern calls in between).

Two run modes:
- Default: libs (torch_scatter / torch_sparse / pyg_lib) enabled. Inductor
           sees torch_scatter ops as extern calls — they don't fuse.
- --disable-libs: libs masked, PyG falls back to native PyTorch
                  scatter_reduce_. This is the case Inductor has the best
                  shot at fusing because it sees the ops directly.

Captures Inductor's `output_code` via `torch._inductor.utils.run_and_get_code`
(or `TORCH_LOGS=output_code` fallback). Counts `@triton.jit` definitions
inside each compile unit; reports graph-break count if any.
"""

from __future__ import annotations

import argparse
import re
import sys
import warnings


def _disable_pyg_libs() -> None:
    for mod in ("torch_scatter", "torch_sparse", "pyg_lib"):
        sys.modules[mod] = None


if "--disable-libs" in sys.argv:
    _disable_pyg_libs()


warnings.filterwarnings("ignore")
import torch  # noqa: E402
import torch._dynamo  # noqa: E402
import torch._dynamo.config as dyn_cfg  # noqa: E402
import torch_geometric.typing as tt  # noqa: E402
from torch_geometric.nn import GATConv  # noqa: E402


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--disable-libs", action="store_true", help=argparse.SUPPRESS
    )  # handled at import time
    p.add_argument("--heads", type=int, default=4)
    p.add_argument("--in-channels", type=int, default=16)
    p.add_argument("--out-channels", type=int, default=8)
    p.add_argument("--nodes", type=int, default=100)
    p.add_argument("--edges", type=int, default=500)
    args = p.parse_args()

    print(f"WITH_TORCH_SCATTER: {tt.WITH_TORCH_SCATTER}")
    print(f"WITH_TORCH_SPARSE : {tt.WITH_TORCH_SPARSE}")
    print(f"WITH_PYG_LIB      : {tt.WITH_PYG_LIB}")
    print(f"torch             : {torch.__version__}")
    print()

    # Reset dynamo state so each invocation gets a fresh compile, and ask it
    # to report any graph breaks. The default verbose=False hides them.
    torch._dynamo.reset()
    dyn_cfg.suppress_errors = False

    torch.manual_seed(0)
    device = torch.device("cuda")
    x = torch.randn(args.nodes, args.in_channels, device=device)
    src = torch.randint(0, args.nodes, (args.edges,), device=device)
    dst = torch.randint(0, args.nodes, (args.edges,), device=device)
    edge_index = torch.stack([src, dst], dim=0)

    conv = (
        GATConv(args.in_channels, args.out_channels, heads=args.heads, concat=True)
        .to(device)
        .eval()
    )

    def forward(x, edge_index):
        with torch.no_grad():
            return conv(x, edge_index)

    # `run_and_get_code` is the standard inductor-testing entry point.
    # Returns (output, [code_string_per_compile_unit]).
    from torch._inductor.utils import run_and_get_code

    compiled = torch.compile(forward, backend="inductor", fullgraph=False)
    try:
        out, codes = run_and_get_code(compiled, x, edge_index)
    except Exception as exc:  # noqa: BLE001
        print(f"compile failed: {type(exc).__name__}: {exc}")
        return 1

    print(f"output shape: {tuple(out.shape)}")
    print(f"compile units: {len(codes)}")
    total_triton = 0
    total_extern = 0
    extern_op_names: set[str] = set()
    for i, code in enumerate(codes):
        # Each `@triton.jit` is a distinct kernel definition.
        n_triton = len(re.findall(r"^@triton\.jit", code, flags=re.M))
        # `extern_kernels.foo(...)` marks where Inductor punts to an existing
        # CUDA library (cuBLAS, cuSPARSE, etc.) instead of generating Triton.
        extern_calls = re.findall(r"extern_kernels\.([a-zA-Z0-9_]+)\(", code)
        # `torch.ops.aten.foo` / `torch.ops.pyg.foo` calls inside the wrapper
        # function (after `def call(...)`) are the runtime extern dispatches.
        aten_calls = re.findall(
            r"torch\.ops\.aten\.([a-zA-Z0-9_]+)\.[a-zA-Z_]+\(",
            code.split("def call(")[-1] if "def call(" in code else "",
        )
        total_triton += n_triton
        total_extern += len(extern_calls)
        extern_op_names.update(extern_calls)
        extern_op_names.update(f"aten.{n}" for n in aten_calls)
        print(
            f"  unit {i}: {n_triton} Triton kernels, "
            f"{len(extern_calls)} extern, "
            f"{len(aten_calls)} aten extern in call()"
        )

    print()
    print(f"TOTAL Triton kernels:  {total_triton}")
    print(f"TOTAL extern calls:    {total_extern}")
    if extern_op_names:
        print("extern ops:", ", ".join(sorted(extern_op_names)))

    # Write the full generated code to a dump so we can read it.
    from pathlib import Path

    out_dir = Path(__file__).parent / "dumps"
    out_dir.mkdir(exist_ok=True)
    suffix = "nolibs" if args.disable_libs else "libs"
    for i, code in enumerate(codes):
        (out_dir / f"gatconv-{suffix}.unit{i}.py").write_text(code)
    print(f"\nFull generated code: {out_dir}/gatconv-{suffix}.unit*.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
