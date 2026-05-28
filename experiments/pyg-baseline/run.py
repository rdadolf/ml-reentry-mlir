"""Day-0 Task 3: PyG baseline measurement.

See internal-docs/short-term-tasks.md §Task 3.

Times the forward pass of GCN, SAGE, and GAT on ogbn-arxiv on a single GPU,
captures peak memory, and prints a machine-and-library fingerprint that
makes the measurement reproducible (or detectably different) later.

Eager mode only — no torch.compile, no Inductor, no manual fusion. That's
the doc's stipulation.
"""

from __future__ import annotations

import argparse
import gc
import json
import platform
import subprocess
import sys
import time
import warnings
from pathlib import Path


def _disable_pyg_libs() -> None:
    """Mask torch_scatter / torch_sparse / pyg_lib so PyG falls back to its
    native-PyTorch scatter implementations.

    Must run BEFORE `import torch_geometric.typing` — that module's
    WITH_* flags are set at import time by `try: import ...`.
    """
    for mod in ("torch_scatter", "torch_sparse", "pyg_lib"):
        sys.modules[mod] = None  # ImportError on subsequent import


if "--disable-libs" in sys.argv:
    _disable_pyg_libs()


import torch  # noqa: E402
import torch_geometric  # noqa: E402
import torch_geometric.typing as tt  # noqa: E402
from ogb.nodeproppred import PygNodePropPredDataset  # noqa: E402

import gnnc._torch_load_compat  # noqa: F401, E402  (PyG safe-globals for OGB)
from examples.models.gat import GAT  # noqa: E402
from examples.models.gcn import GCN  # noqa: E402
from examples.models.sage import SAGE  # noqa: E402
from gnnc.paths import DATA_DIR  # noqa: E402

warnings.filterwarnings("ignore")


def gpu_info() -> dict:
    if not torch.cuda.is_available():
        return {"cuda_available": False}
    name = torch.cuda.get_device_name(0)
    cc = torch.cuda.get_device_capability(0)
    # Driver reports CUDA version; toolkit version comes from PyTorch's build.
    smi = subprocess.run(
        ["nvidia-smi", "--query-gpu=driver_version", "--format=csv,noheader"],
        capture_output=True,
        text=True,
        check=False,
    )
    driver = smi.stdout.strip() if smi.returncode == 0 else "?"
    return {
        "cuda_available": True,
        "gpu_name": name,
        "compute_capability": f"sm_{cc[0]}{cc[1]}",
        "driver_version": driver,
        "torch_cuda_version": torch.version.cuda,
        "device_count": torch.cuda.device_count(),
    }


def env_fingerprint() -> dict:
    return {
        "platform": platform.platform(),
        "python": platform.python_version(),
        "torch": torch.__version__,
        "torch_geometric": torch_geometric.__version__,
        "WITH_TORCH_SCATTER": bool(tt.WITH_TORCH_SCATTER),
        "WITH_TORCH_SPARSE": bool(tt.WITH_TORCH_SPARSE),
        "WITH_PYG_LIB": bool(tt.WITH_PYG_LIB),
        "gpu": gpu_info(),
    }


def time_forward(
    model: torch.nn.Module,
    x: torch.Tensor,
    edge_index: torch.Tensor,
    *,
    n_warmup: int,
    n_timed: int,
) -> dict:
    model.eval()
    device = x.device

    # Warmup: includes any one-time kernel JIT or cudnn-bench search.
    with torch.no_grad():
        for _ in range(n_warmup):
            _ = model(x, edge_index)
    if device.type == "cuda":
        torch.cuda.synchronize()

    # Reset peak-memory counter AFTER warmup so we measure steady-state
    # working-set, not first-iter allocator slack.
    if device.type == "cuda":
        torch.cuda.reset_peak_memory_stats(device)

    # Timed runs. CUDA events are the right granularity for short kernels;
    # wall-clock would dominate at this scale because of CPU↔GPU sync.
    if device.type == "cuda":
        starts = [torch.cuda.Event(enable_timing=True) for _ in range(n_timed)]
        stops = [torch.cuda.Event(enable_timing=True) for _ in range(n_timed)]
        with torch.no_grad():
            for i in range(n_timed):
                starts[i].record()
                _ = model(x, edge_index)
                stops[i].record()
        torch.cuda.synchronize()
        times_ms = [s.elapsed_time(e) for s, e in zip(starts, stops, strict=False)]
    else:
        times_ms = []
        with torch.no_grad():
            for _ in range(n_timed):
                t0 = time.perf_counter()
                _ = model(x, edge_index)
                times_ms.append((time.perf_counter() - t0) * 1000)

    times_ms.sort()
    n = len(times_ms)
    stats = {
        "n_warmup": n_warmup,
        "n_timed": n_timed,
        "min_ms": times_ms[0],
        "median_ms": times_ms[n // 2],
        "p90_ms": times_ms[int(n * 0.9)],
        "max_ms": times_ms[-1],
        "mean_ms": sum(times_ms) / n,
    }
    if device.type == "cuda":
        peak = torch.cuda.max_memory_allocated(device)
        reserved = torch.cuda.max_memory_reserved(device)
        stats["peak_allocated_mib"] = peak / (1024 * 1024)
        stats["peak_reserved_mib"] = reserved / (1024 * 1024)
    return stats


def build_model(name: str, in_ch: int, out_ch: int) -> torch.nn.Module:
    torch.manual_seed(0)
    if name == "gcn":
        return GCN(in_ch, 64, out_ch)
    if name == "sage":
        return SAGE(in_ch, 64, out_ch)
    if name == "gat":
        return GAT(in_ch, 64, out_ch, heads=4)
    raise ValueError(name)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--device", default="cuda")
    p.add_argument("--n-warmup", type=int, default=20)
    p.add_argument("--n-timed", type=int, default=100)
    p.add_argument("--dataset", default="ogbn-arxiv", choices=["ogbn-arxiv"])
    p.add_argument("--out", default=str(Path(__file__).parent / "results.json"))
    p.add_argument(
        "--disable-libs",
        action="store_true",
        help="Mask torch_scatter/torch_sparse/pyg_lib so PyG uses its native "
        "PyTorch scatter fallback (apples-to-apples comparison against "
        "a libs-enabled run on the same torch version).",
    )
    p.add_argument(
        "--compile",
        action="store_true",
        help="Wrap each model in torch.compile(...) before warmup. Compile "
        "time is absorbed by the warmup iterations (Dynamo + Inductor "
        "first-call overhead) and excluded from per-iter timing.",
    )
    p.add_argument(
        "--n-warmup-compile",
        type=int,
        default=50,
        help="Larger warmup count when --compile is set, to absorb the slow "
        "first-iter compile and any recompile triggered by graph breaks.",
    )
    args = p.parse_args()

    fingerprint = env_fingerprint()
    print(json.dumps(fingerprint, indent=2))

    device = torch.device(args.device)
    print(f"\nloading {args.dataset} ...")
    ds = PygNodePropPredDataset(name=args.dataset, root=str(DATA_DIR / "ogb"))
    data = ds[0]
    x = data.x.to(device)
    edge_index = data.edge_index.to(device)
    in_ch = data.num_features
    out_ch = ds.num_classes
    print(f"  nodes={data.num_nodes:,} edges={data.num_edges:,} features={in_ch} classes={out_ch}")

    results = {}
    n_warmup = args.n_warmup_compile if args.compile else args.n_warmup
    for model_name in ["gcn", "sage", "gat"]:
        print(f"\n=== {model_name} ===")
        model = build_model(model_name, in_ch, out_ch).to(device)
        n_params = sum(p.numel() for p in model.parameters())
        print(f"  params: {n_params:,}")

        if args.compile:
            # Fresh dynamo state per model so we don't measure cache hits
            # across models. fullgraph=False lets us tolerate graph breaks
            # (which there will be — see the inductor-fusion experiment).
            import torch._dynamo as _dynamo

            _dynamo.reset()
            model = torch.compile(model, backend="inductor", fullgraph=False)

        stats = time_forward(
            model,
            x,
            edge_index,
            n_warmup=n_warmup,
            n_timed=args.n_timed,
        )
        print(
            f"  median: {stats['median_ms']:.3f} ms, "
            f"p90: {stats['p90_ms']:.3f} ms, "
            f"peak_mem: {stats.get('peak_allocated_mib', 0):.1f} MiB"
        )
        results[model_name] = {"params": n_params, **stats}

        del model
        gc.collect()
        if device.type == "cuda":
            torch.cuda.empty_cache()

    out_path = Path(args.out)
    out_path.write_text(
        json.dumps(
            {
                "dataset": args.dataset,
                "env": fingerprint,
                "results": results,
            },
            indent=2,
        )
    )
    print(f"\nWrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
