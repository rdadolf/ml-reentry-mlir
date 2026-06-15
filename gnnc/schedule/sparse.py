"""Pipeline composition for sparse-tensor lowering.

Decomposed from `buildSparsifier`. Inner `sparsification-and-bufferization`
stays monolithic per the Q1 design decision; the per-pass rationale and
side-by-side with upstream/MPACT lives in
[internal-docs/sparse-pipeline-comparison.md](../../internal-docs/sparse-pipeline-comparison.md).

The schedule is grouped into named phases (`gnnc.pipeline.phase.PhasePipeline`)
so a caller can halt at a boundary (`--stop-after sparsify`) or print the IR there.
"""

from __future__ import annotations

from gnnc.pipeline.phase import PhasePipeline

# Knobs.
_VL = 0  # sparse vectorization lane count; 16=AVX-512, 8=AVX2, 4=SSE/NEON
_SPARSE_ITERATOR = False  # use experimental `sparse_tensor.iterate` emit strategy


def build_pipeline(
    *,
    target: str,
    gpu_chip: str = "sm_89",
    gpu_features: str = "+ptx80",
    gpu_num_threads: int = 128,
) -> PhasePipeline:
    if target not in ("cpu", "gpu"):
        raise NotImplementedError(f"target {target!r} not supported")

    pipeline = PhasePipeline()

    with pipeline.add_phase("func-prep") as phase:
        # Mark @main so the JIT engine can call it via the C ABI.
        phase.add_pass("func.func(llvm-request-c-wrappers)")

    with pipeline.add_phase("sparse-prep") as phase:
        # Decompose sparse fn args into the dense components the runtime expects.
        phase.add_pass("sparse-assembler{direct-out}")
        phase.add_pass("func.func(linalg-generalize-named-ops)")
        # Hoisted from inner pass so FuseTensorCast folds dense->sparse casts
        # into producer linalg.generic ops *before* elementwise fusion locks
        # them in. The hoist is the difference between SAGE compiling and not.
        phase.add_pass("pre-sparsification-rewrite")
        phase.add_pass("func.func(linalg-fuse-elementwise-ops)")

    with pipeline.add_phase("sparsify") as phase:
        # The inner monolith. `enable-runtime-library` is not a textual option
        # on this pass (only on `--sparsifier`); the no-options default is
        # `false`, which is what we want — the codegen path is canonical and
        # the runtime-library path hits an i1-storage abort on SAGE.
        sb_opts = []
        if target == "gpu":
            sb_opts.append("parallelization-strategy=dense-outer-loop")
        if _VL > 0:
            sb_opts.append(f"vl={_VL} enable-simd-index32")
        if _SPARSE_ITERATOR:
            sb_opts.append("sparse-emit-strategy=sparse-iterator")
        sb = "sparsification-and-bufferization"
        if sb_opts:
            sb += "{" + " ".join(sb_opts) + "}"
        phase.add_pass(sb)

    with pipeline.add_phase("sparse-to-llvm") as phase:
        phase.add_pass("sparse-storage-specifier-to-llvm")
        phase.add_pass("func.func(canonicalize)")

    if target == "gpu":
        with pipeline.add_phase("gpu-codegen") as phase:
            # Pulls sparse kernels into gpu.module bodies, emits launch_func at host.
            phase.add_pass(
                f"sparse-gpu-codegen{{num-threads={gpu_num_threads} enable-runtime-library=false}}"
            )
            # NVVM's lowering doesn't tolerate debug-info ops in kernel bodies.
            phase.add_pass("gpu.module(strip-debuginfo)")
            phase.add_pass("gpu.module(convert-scf-to-cf)")
            phase.add_pass("gpu.module(convert-gpu-to-nvvm)")

    with pipeline.add_phase("bufferized-lower") as phase:
        phase.add_pass("func.func(convert-linalg-to-loops)")
        phase.add_pass("func.func(convert-vector-to-scf)")
        # LLVM has no realloc primitive; expand to alloc + copy + dealloc here.
        phase.add_pass("func.func(expand-realloc)")
        phase.add_pass("func.func(convert-scf-to-cf)")
        phase.add_pass("expand-strided-metadata")
        phase.add_pass("lower-affine")
        phase.add_pass("convert-vector-to-llvm")
        phase.add_pass("func.func(convert-complex-to-standard)")
        phase.add_pass("func.func(arith-expand)")
        phase.add_pass("func.func(convert-math-to-llvm)")
        # tanh/erf/cexp/clog and friends have no LLVM intrinsic; route to libm.
        phase.add_pass("convert-math-to-libm")
        phase.add_pass("convert-complex-to-libm")
        # Second pass cleans up vector ops re-introduced by the math/complex
        # lowerings above — the first convert-vector-to-llvm didn't see them.
        phase.add_pass("convert-vector-to-llvm")

    if target == "gpu":
        with pipeline.add_phase("gpu-finalize") as phase:
            # NVVM consumes triple/chip/features as attrs on gpu.module.
            phase.add_pass(
                f"nvvm-attach-target{{triple=nvptx64-nvidia-cuda chip={gpu_chip} features={gpu_features}}}"
            )
            # Host-side gpu.* -> mgpuStream*/mgpuLaunchKernel runtime calls.
            phase.add_pass("gpu-to-llvm")
            # Serialize device-side gpu.module(s) to a fatbinary blob.
            phase.add_pass("gpu-module-to-binary{format=fatbin}")

    with pipeline.add_phase("llvm-lower") as phase:
        # Umbrella over the remaining func/cf/arith/index/complex -> LLVM lowerings.
        phase.add_pass("convert-to-llvm")
        phase.add_pass("reconcile-unrealized-casts")

    return pipeline
