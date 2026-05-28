"""GAT-shaped fused-loop probe for gpu-codegen. See README.md.

Lowers gat-kernel.mlir through two pipelines, executes both via mlir-runner,
and verifies:

  (1) gpu-codegen lowered IR has gpu.binary + gpu.launch_func calls + a
      native NVVM target attached, and zero cuSPARSE / mgpu* library
      symbols (this is the codegen-vs-library distinction the M3 fusion
      thesis depends on);
  (2) GPU output matches CPU within rtol=1e-3 / atol=1e-4.

Emits a GREEN / YELLOW / RED line. RED ⇒ halt project (no project-level
recovery path if gpu-codegen can't handle this shape).
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

LLVM_BUILD = os.environ.get("LLVM_BUILD", "/x/cache/build/llvm")
MLIR_OPT = f"{LLVM_BUILD}/bin/mlir-opt"
MLIR_RUNNER = f"{LLVM_BUILD}/bin/mlir-runner"
CUDA_RT = f"{LLVM_BUILD}/lib/libmlir_cuda_runtime.so"
C_RT = f"{LLVM_BUILD}/lib/libmlir_c_runner_utils.so"
RT = f"{LLVM_BUILD}/lib/libmlir_runner_utils.so"

HERE = Path(__file__).parent
KERNEL = HERE / "gat-kernel.mlir"
OUT = HERE / "dumps"
OUT.mkdir(exist_ok=True)

# GPU target — RTX 4070 is sm_89 (Ada Lovelace). +ptx80 unlocks the codegen
# features the sparsifier emits. fatbin embeds CUBIN+PTX.
GPU_TARGET = "gpu-triple=nvptx64-nvidia-cuda gpu-chip=sm_89 gpu-features=+ptx80 gpu-format=fatbin"

CPU_OPTS = "enable-runtime-library=true"
GPU_OPTS = (
    f"enable-runtime-library=false parallelization-strategy=dense-outer-loop "
    f"gpu-num-threads=128 {GPU_TARGET}"
)

# Forbidden library symbols. The M3 fusion thesis needs native codegen, not
# library dispatch — any of these in the lowered GPU IR would violate the
# pass condition.
FORBIDDEN_SYMS = [
    "cuSPARSE",
    "mgpuSpMM",
    "mgpuSDDMM",
    "mgpuCreateSparseEnv",
    "mgpuCreateCsr",
    "mgpuCreateDnTensor",
]


def lower(opts: str, out_path: Path) -> tuple[int, str]:
    """Pipe the kernel through `mlir-opt --sparsifier=<opts>`."""
    p = subprocess.run(
        [MLIR_OPT, str(KERNEL), f"--sparsifier={opts}"],
        capture_output=True,
        text=True,
    )
    out_path.write_text(p.stdout)
    out_path.with_suffix(".stderr.txt").write_text(p.stderr)
    return p.returncode, p.stderr


def execute(lowered: Path, out_path: Path) -> tuple[int, str]:
    """Run the lowered IR through mlir-runner; capture stdout+stderr together."""
    p = subprocess.run(
        [
            MLIR_RUNNER,
            f"--shared-libs={CUDA_RT}",
            f"--shared-libs={C_RT}",
            f"--shared-libs={RT}",
            "-e",
            "main",
            "--entry-point-result=void",
            str(lowered),
        ],
        capture_output=True,
        text=True,
    )
    out_path.write_text(p.stdout + p.stderr)
    return p.returncode, p.stdout + p.stderr


def parse_output(path: Path) -> list[float]:
    """Extract all f32 values from a printMemrefF32 dump."""
    text = path.read_text()
    return [float(x) for x in re.findall(r"-?\d+\.\d+(?:e-?\d+)?", text)]


def main() -> int:
    print("== GAT-shaped fused-loop gpu-codegen probe ==")
    print(f"  LLVM_BUILD = {LLVM_BUILD}")
    print(f"  KERNEL     = {KERNEL}")
    print()

    # ---------- CPU lower + run ----------
    print("[cpu] lowering …", end=" ", flush=True)
    rc, err = lower(CPU_OPTS, OUT / "cpu.lowered.mlir")
    if rc != 0:
        print(f"FAIL ({rc})")
        print(err[:500], file=sys.stderr)
        print("\nVERDICT: RED — CPU lowering failed (project-halting).")
        return 2
    print("ok")

    print("[cpu] running  …", end=" ", flush=True)
    rc, out_text = execute(OUT / "cpu.lowered.mlir", OUT / "cpu.out.txt")
    if rc != 0 or "Failed to materialize" in out_text or "JIT session error" in out_text:
        print(f"FAIL ({rc})")
        print(out_text[:500], file=sys.stderr)
        print("\nVERDICT: RED — CPU execution failed.")
        return 2
    print("ok")

    # ---------- GPU-codegen lower + run ----------
    print("[gpu] lowering …", end=" ", flush=True)
    rc, err = lower(GPU_OPTS, OUT / "gpu-codegen.lowered.mlir")
    if rc != 0:
        print(f"FAIL ({rc})")
        print(err[:1000], file=sys.stderr)
        print("\nVERDICT: RED — gpu-codegen lowering failed.")
        return 2
    print("ok")

    print("[gpu] running  …", end=" ", flush=True)
    rc, gpu_out = execute(OUT / "gpu-codegen.lowered.mlir", OUT / "gpu-codegen.out.txt")
    if rc != 0 or "Failed to materialize" in gpu_out or "JIT session error" in gpu_out:
        print(f"FAIL ({rc})")
        print(gpu_out[:500], file=sys.stderr)
        print("\nVERDICT: RED — GPU execution failed.")
        return 2
    print("ok")

    # ---------- pass-condition checks on lowered IR ----------
    print()
    print("== pass conditions ==")
    lowered_ir = (OUT / "gpu-codegen.lowered.mlir").read_text()
    n_binary = lowered_ir.count("gpu.binary")
    n_launch = lowered_ir.count("gpu.launch_func")
    n_nvvm = lowered_ir.count("nvvm.target")
    n_kernels = len(set(re.findall(r"\bkernel\d+\b", lowered_ir)))
    forbidden = {s: lowered_ir.count(s) for s in FORBIDDEN_SYMS if lowered_ir.count(s) > 0}

    print(f"  gpu.binary blocks       : {n_binary}    (need ≥1)")
    print(f"  gpu.launch_func calls   : {n_launch}    (need ≥1)")
    print(f"  nvvm.target attrs       : {n_nvvm}    (need ≥1)")
    print(f"  distinct kernels in bin : {n_kernels}    (informational)")
    print(f"  forbidden library syms  : {forbidden if forbidden else '(none)'}    (need empty)")

    cond_codegen = n_binary >= 1 and n_launch >= 1 and n_nvvm >= 1
    cond_no_lib = len(forbidden) == 0

    # ---------- numerical compare ----------
    print()
    print("== numerical comparison (CPU vs GPU) ==")
    c_vals = parse_output(OUT / "cpu.out.txt")
    g_vals = parse_output(OUT / "gpu-codegen.out.txt")
    if len(c_vals) != len(g_vals):
        print(f"  count mismatch: cpu={len(c_vals)}, gpu={len(g_vals)}")
        cond_numerics = False
        max_abs = max_rel = float("nan")
    else:
        diffs = [abs(a - b) for a, b in zip(c_vals, g_vals, strict=False)]
        max_abs = max(diffs) if diffs else 0.0
        rels = [
            abs(a - b) / max(abs(a), abs(b), 1e-12) for a, b in zip(c_vals, g_vals, strict=False)
        ]
        max_rel = max(rels) if rels else 0.0
        print(f"  n_floats compared : {len(c_vals)}")
        print(f"  max abs diff      : {max_abs:.3e}    (tolerance atol=1e-4)")
        print(f"  max rel diff      : {max_rel:.3e}    (tolerance rtol=1e-3)")
        cond_numerics = max_abs <= 1e-4 and max_rel <= 1e-3

    # ---------- verdict ----------
    print()
    if cond_codegen and cond_no_lib and cond_numerics:
        verdict = "GREEN"
        explain = (
            "gpu-codegen lowered to native NVVM kernels (no library fallback) "
            "and numerical output matches CPU within tolerance."
        )
    elif cond_codegen and cond_numerics and not cond_no_lib:
        verdict = "YELLOW"
        explain = (
            "GPU kernels produced and numerics match, but lowered IR contains "
            f"library symbols: {forbidden}. The M3 fusion thesis requires native "
            "codegen; this is a project-level concern but not a hard halt."
        )
    elif cond_codegen and cond_no_lib and not cond_numerics:
        verdict = "YELLOW"
        explain = (
            f"Codegen path clean but numerics diverge (max abs {max_abs:.3e} > 1e-4 "
            f"or max rel {max_rel:.3e} > 1e-3). Worth investigating before M2."
        )
    else:
        verdict = "RED"
        explain = (
            f"codegen={'OK' if cond_codegen else 'FAIL'} "
            f"no-lib={'OK' if cond_no_lib else 'FAIL'} "
            f"numerics={'OK' if cond_numerics else 'FAIL'}. "
            "Halt project for re-planning."
        )

    print(f"VERDICT: {verdict}")
    print(explain)
    return 0 if verdict == "GREEN" else (1 if verdict == "YELLOW" else 2)


if __name__ == "__main__":
    sys.exit(main())
