"""Pipeline composition for sparse-tensor lowering recipes.

Decomposed from `buildSparsifier`. Inner `sparsification-and-bufferization`
stays monolithic per the Q1 design decision; the per-pass rationale and
side-by-side with upstream/MPACT lives in
[internal-docs/sparse-pipeline-comparison.md](../../internal-docs/sparse-pipeline-comparison.md).
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from lighthouse.pipeline.descriptor import Descriptor
from lighthouse.pipeline.driver import PipelineDriver

if TYPE_CHECKING:
    from mlir import ir


# Knobs.
_VL = 0  # sparse vectorization lane count; 16=AVX-512, 8=AVX2, 4=SSE/NEON
_SPARSE_ITERATOR = False  # use experimental `sparse_tensor.iterate` emit strategy


def build_pipeline(
    *,
    ctx: ir.Context,
    target: str,
    has_sparse: bool = True,
    gpu_chip: str = "sm_89",
    gpu_features: str = "+ptx80",
    gpu_num_threads: int = 128,
) -> PipelineDriver:
    if target not in ("cpu", "gpu"):
        raise NotImplementedError(f"target {target!r} not supported")

    driver = PipelineDriver(ctx)
    # Mark @main so the JIT engine can call it via the C ABI.
    driver.add_pass(Descriptor("func.func(llvm-request-c-wrappers)"))

    if has_sparse:
        # Decompose sparse fn args into the dense components the runtime expects.
        driver.add_pass(Descriptor("sparse-assembler{direct-out}"))
        driver.add_pass(Descriptor("func.func(linalg-generalize-named-ops)"))
        # Hoisted from inner pass so FuseTensorCast folds dense->sparse casts
        # into producer linalg.generic ops *before* elementwise fusion locks
        # them in. The hoist is the difference between SAGE compiling and not.
        driver.add_pass(Descriptor("pre-sparsification-rewrite"))
        driver.add_pass(Descriptor("func.func(linalg-fuse-elementwise-ops)"))

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
        driver.add_pass(Descriptor(sb))

        driver.add_pass(Descriptor("sparse-storage-specifier-to-llvm"))
        driver.add_pass(Descriptor("func.func(canonicalize)"))

        if target == "gpu":
            # Pulls sparse kernels into gpu.module bodies, emits launch_func at host.
            driver.add_pass(
                Descriptor(
                    f"sparse-gpu-codegen{{num-threads={gpu_num_threads} enable-runtime-library=false}}"
                )
            )
            # NVVM's lowering doesn't tolerate debug-info ops in kernel bodies.
            driver.add_pass(Descriptor("gpu.module(strip-debuginfo)"))
            driver.add_pass(Descriptor("gpu.module(convert-scf-to-cf)"))
            driver.add_pass(Descriptor("gpu.module(convert-gpu-to-nvvm)"))

        driver.add_pass(Descriptor("func.func(convert-linalg-to-loops)"))
        driver.add_pass(Descriptor("func.func(convert-vector-to-scf)"))
        # LLVM has no realloc primitive; expand to alloc + copy + dealloc here.
        driver.add_pass(Descriptor("func.func(expand-realloc)"))
        driver.add_pass(Descriptor("func.func(convert-scf-to-cf)"))
        driver.add_pass(Descriptor("expand-strided-metadata"))
        driver.add_pass(Descriptor("lower-affine"))
        driver.add_pass(Descriptor("convert-vector-to-llvm"))
        driver.add_pass(Descriptor("func.func(convert-complex-to-standard)"))
        driver.add_pass(Descriptor("func.func(arith-expand)"))
        driver.add_pass(Descriptor("func.func(convert-math-to-llvm)"))
        # tanh/erf/cexp/clog and friends have no LLVM intrinsic; route to libm.
        driver.add_pass(Descriptor("convert-math-to-libm"))
        driver.add_pass(Descriptor("convert-complex-to-libm"))
        # Second pass cleans up vector ops re-introduced by the math/complex
        # lowerings above — the first convert-vector-to-llvm didn't see them.
        driver.add_pass(Descriptor("convert-vector-to-llvm"))

        if target == "gpu":
            # NVVM consumes triple/chip/features as attrs on gpu.module.
            driver.add_pass(
                Descriptor(
                    f"nvvm-attach-target{{triple=nvptx64-nvidia-cuda chip={gpu_chip} features={gpu_features}}}"
                )
            )
            # Host-side gpu.* -> mgpuStream*/mgpuLaunchKernel runtime calls.
            driver.add_pass(Descriptor("gpu-to-llvm"))
            # Serialize device-side gpu.module(s) to a fatbinary blob.
            driver.add_pass(Descriptor("gpu-module-to-binary{format=fatbin}"))

        # Umbrella over the remaining func/cf/arith/index/complex -> LLVM lowerings.
        driver.add_pass(Descriptor("convert-to-llvm"))
        driver.add_pass(Descriptor("reconcile-unrealized-casts"))

    else:
        # No sparse content: skip the sparsifier; lean on Lighthouse's bundled chain.
        driver.add_descriptor(Descriptor("bufferization.yaml"))
        driver.add_descriptor(Descriptor("bufferization_cleanup.yaml"))
        driver.add_pass(Descriptor("convert-linalg-to-loops"))
        driver.add_descriptor(Descriptor("llvm_lowering.yaml"))
        driver.add_descriptor(Descriptor("cleanup.yaml"))

    return driver
