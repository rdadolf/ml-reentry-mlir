# Task 2: sparsifier GPU codegen state

**Assessment: GREEN.**

Both GPU paths of `--sparsifier` produce functional GPU code on this machine.
A hand-written 8×8 CSR-SpMM lowers through each pipeline, executes on the
RTX 4070, and produces output bit-identical to the CPU baseline:

| Variant | Status |
|---|---|
| `cpu` (sparsifier+RT lib, no GPU) | baseline |
| `gpu-codegen` (direct NVVM via `--gpu-num-threads`) | bit-identical |
| `gpu-libgen` (cuSPARSE wrappers via `--enable-gpu-libgen`) | bit-identical |

`gpu-libgen` initially failed because our LLVM build was missing the
cuSPARSE-aware runtime symbols. That was a one-flag CMake fix
(`MLIR_ENABLE_CUDA_CUSPARSE=ON`), already applied to
[tools/build-llvm.sh](../tools/build-llvm.sh). See "`gpu-libgen` history"
below.

Source artifacts:
[experiments/day-zero/task-2-gpu-sparsifier/](../experiments/day-zero/task-2-gpu-sparsifier/).
Run script:
[run.sh](../experiments/day-zero/task-2-gpu-sparsifier/run.sh).

Pinned commits at characterization time:
[third_party/README.md](../third_party/README.md). Hardware: RTX 4070
(sm_89, Ada Lovelace), driver R581.57, CUDA 13.0 toolkit.

---

## Procedure

A small hand-written sparse SpMM
([spmm-cpu.mlir](../experiments/day-zero/task-2-gpu-sparsifier/spmm-cpu.mlir),
also [spmm-gpu.mlir](../experiments/day-zero/task-2-gpu-sparsifier/spmm-gpu.mlir)
for the libgen path which needs `mgpuCreateSparseEnv` setup) computes
`C = A · B` where A is 8×8 CSR (~1/3 fill, deterministic pattern), B and C
are 8×8 dense. The kernel is `linalg.matmul` on a sparse-typed operand —
the same shape that Task 1's green path produces from torch-mlir.

The driver `run.sh` exercises three pipelines:

| Variant | Sparsifier opts |
|---|---|
| `cpu` | `enable-runtime-library=true` |
| `gpu-libgen` | `enable-runtime-library=true enable-gpu-libgen gpu-triple=... gpu-chip=sm_89 gpu-features=+ptx80 gpu-format=fatbin` |
| `gpu-codegen` | `enable-runtime-library=false parallelization-strategy=dense-outer-loop gpu-num-threads=128 gpu-triple=... ...` |

Each variant is then executed via `mlir-runner` with the three runtime
libraries on `--shared-libs` (CUDA runtime, C runner utils, runner utils).
Stdout is captured and compared against the CPU baseline.

---

## Results

### `cpu` — baseline

Works.
([cpu.out.txt](../experiments/day-zero/task-2-gpu-sparsifier/dumps/cpu.out.txt)).
Produces the expected `(C[i][j])` for `i,j ∈ [0,8)`.

### `gpu-codegen` — direct GPU codegen via the sparsifier

**Works, bit-identical to CPU output**
([gpu-codegen.out.txt](../experiments/day-zero/task-2-gpu-sparsifier/dumps/gpu-codegen.out.txt)).
Lowered IR contains a `gpu.module` with an emitted NVVM kernel and
explicit `mgpuMemAlloc`/`mgpuMemcpy`/`mgpuLaunchKernel`/`mgpuStreamCreate`
calls — **no cuSPARSE symbols**, only the generic CUDA runtime wrappers
that ship with stock `MLIR_ENABLE_CUDA_RUNNER=ON`.

What it took to make this path trigger:

1. `--gpu-num-threads=N` alone is not enough. With the default options
   (`enable-runtime-library=true`, `parallelization-strategy=none`),
   `--sparsifier` produces the same IR with and without `--gpu-num-threads`
   — byte-identical to the CPU output. The `LinalgOpRewriter` in
   [SparseGPUCodegen.cpp](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Transforms/SparseGPUCodegen.cpp)
   matches only `linalg.generic`, and the `ForallRewriter` matches only
   `scf.parallel` with the loop-emitter attribute and no reductions; the
   default `parallelization=none` path generates neither.
2. Two flags are load-bearing:
   - `parallelization-strategy=dense-outer-loop` — makes the sparsifier
     emit an `scf.parallel` over the outer (dense) dimension, which is
     what `ForallRewriter` matches.
   - `enable-runtime-library=false` — without this, sparse-tensor
     manipulation goes through library calls and the parallel loop never
     materializes in a form the GPU pass recognizes.
3. The GPU-triple group (`gpu-triple gpu-chip gpu-features gpu-format`)
   then drives the rest of the pipeline (`createGpuNVVMAttachTarget`,
   `convert-gpu-ops-to-nvvm`).

This is the **canonical "MLIR all the way down" GPU SpMM path** the project
plan relies on for the cuSPARSE-bypass goal.

### `gpu-libgen` — sparsifier-driven cuSPARSE wrappers

**Works, bit-identical to CPU output**
([gpu-libgen.out.txt](../experiments/day-zero/task-2-gpu-sparsifier/dumps/gpu-libgen.out.txt)).
The lowering generates the expected
`mgpuCreateSparseEnv → mgpuCreateCsr → mgpuCreateDnMat → mgpuSpMMBufferSize → mgpuSpMM → mgpuDestroy*`
call sequence
([gpu-libgen.lowered.mlir](../experiments/day-zero/task-2-gpu-sparsifier/dumps/gpu-libgen.lowered.mlir)),
which dispatches to NVIDIA's cuSPARSE library at runtime.

#### `gpu-libgen` history

This path was initially red — `mlir-runner` rejected execution with:

```
JIT session error: Symbols not found: [ mgpuCreateSparseEnv,
  mgpuDestroySparseEnv, mgpuCreateCsr, mgpuCreateDnMat, mgpuDestroySpMat,
  mgpuDestroyDnMat, mgpuSpMM, mgpuSpMMBufferSize ]
```

These wrappers ship in `libmlir_cuda_runtime.so` only when LLVM is
configured with `MLIR_ENABLE_CUDA_CUSPARSE=ON`, which adds a `libcusparse`
link dep. Our initial build had `MLIR_ENABLE_CUDA_RUNNER=ON` but not the
cuSPARSE extension.

Fix: added `-DMLIR_ENABLE_CUDA_CUSPARSE=ON` to
[tools/build-llvm.sh](../tools/build-llvm.sh) and rebuilt (12-step
incremental — only `CudaRuntimeWrappers.cpp` and the .so relink). After
rebuild, `nm -D libmlir_cuda_runtime.so` shows all 10 cuSPARSE-flavored
`mgpu*` symbols, and the variant runs cleanly.

The 2:4 sparse-tensor-core variant (`MLIR_ENABLE_CUDA_CUSPARSELT=ON`)
remains off — the project-summary scope decisions rule out sparse tensor
cores ("useless for graph-scale sparsity"), so enabling it would just
bloat the runtime with unused code. Revisit only if we ever care about
2:4 sparse for dense-side ops (e.g., model weights).

---

## Strategy implication

Both GPU paths work at our pinned LLVM commit on this GPU/driver/toolkit.

The **direct codegen** path is the one we care about long-term, because
the project's "beat cuSPARSE on GAT" thesis demands generated GPU code.

The **libgen** path now also works and is the right reference for the
"matches cuSPARSE on GCN-class SpMM" intermediate target — having it
available means we can A/B our generated GPU code against the cuSPARSE
implementation by flipping a single sparsifier flag, on the same hand-built
IR. That's a nice property for week-2 measurements.

---

## Open follow-ups (per the doc's yellow conditions)

The doc lists "mean/max reductions, multi-dim feature tensors, etc." as
things to check. The minimal test exercised sum-reduction over `f32`.
Things still unverified:

- **Non-sum reductions** (mean, max). GCN uses sum and SAGE uses
  mean-after-sum; GAT effectively uses sum after softmax weighting. The
  direct codegen path currently only matches the loop-emitter `scf.parallel`
  shape, not arbitrary reductions — needs an explicit test before week 2.
- **Multi-dim feature tensors.** Real GNNs have B×D feature matrices.
  Our 8×8 test stresses 1D-per-row aggregation only when the dense
  operand has F=8 columns. Worth re-running with a wider F to ensure the
  generated GPU kernel still vectorizes well; the `parallelization` flag
  only parallelizes outer loops.
- **CSR with int64 indices.** Our pin used `posWidth=32, crdWidth=32`.
  ogbn-arxiv (170k nodes, 1.2M edges) fits, but ogbn-products (2.4M
  nodes, 61M edges) overflows int32 in some count fields. Verify the
  GPU codegen path with `posWidth=64` before any stretch experiments.
- **larger matrix sizes.** 8×8 is a smoke test. Verify nothing breaks at
  ogbn-arxiv-scale (170k×170k @ ~0.004% fill).
