# Upstream Fix/Feature Wishlist

## [torch-mlir] MLIR-style type properties for `vtensor`/`tensor`

**Problem:**
torch-mlir binds its dialect ops to Python but not its types — no `VTensorType.get(...)` factory, no `.shape` / `.element_type` / `.encoding` accessors, no `.isinstance(t)`. The C API in `torch-mlir-c/TorchTypes.h` is complete; only the Python pybind/nanobind layer is missing. Downstream Python users fall back to text round-trip on `str(t)` (see `gnnc/conversion/tm_tensor_to_torch/util.py` for what the workaround looks like).

**Preferred fix:**
Add nanobind bindings for `ValueTensorType`, `NonValueTensorType`, container types (`ListType`, `OptionalType`, `TupleType`, …), and primitive types — modeled on upstream MLIR's `mlir/lib/Bindings/Python/IRTypes.cpp` (specifically `PyRankedTensorType`). One C API gap to close first: add `torchMlirTorchValueTensorTypeGetSparsity` (and the NonValue parallel) — the current C API has a sparsity constructor argument but no readback.

## [mlir] Python bindings for `notify_match_failure` and `Operation.emit_*`

**Problem:**
The Python `mlir.rewrite.PatternRewriter` exposes only `replace_op`, `erase_op`, and `ip` — no `notify_match_failure(op, msg)`. And `Operation` has no `emit_error` / `emit_warning` / `emit_remark` at all; the only bound emit surface is `Location.emit_error`, which lacks warning/remark counterparts. C++ patterns lean heavily on both: `notifyMatchFailure` for soft bails (logged via `--debug-only=greedy-rewriter`) and `op.emit{Error,Warning,Remark}` for IR-located diagnostics. Python rewrites have no equivalent — they print to stderr, raise, or stay silent.

**Preferred fix:**
Bind `Operation.emit_error/_warning/_remark` and `Location.emit_warning/_remark` (parallel to the existing `Location.emit_error`); add `PatternRewriter.notify_match_failure(op, msg)`. All four C API hooks (`mlirEmitError`, `mlirOperationEmitOpError`, etc.) already exist — this is small nanobind glue, structurally parallel to how the IR types are bound.

## [mlir] `gpu-to-llvm` emits double-destroy on `gpu.wait` operands that alias one stream

**Problem:**
In `ConvertWaitOpToGpuRuntimeCallPattern` (`mlir/lib/Conversion/GPUCommon/GPUToLLVMConversion.cpp:879-902`), the code emits `mgpuStreamDestroy` calls for each `gpu.wait` insn. There's an invariant warning about not using the stream before or after, but unfortunately, multiple async ops that wait on the same stream violate this pretty easily. I.e., two `memcpy` using the same launch reference, then `gpu.wait`ing on both `memcpy` return values triggers violates this invariant. The sparse tensor gpu path emits this often. The second `mgpuStreamSynchronize` call after the `mgpuStreamDestory` causes a segfault.

Note that `ConvertAsyncYieldToGpuRuntimeCallPattern` already uses a `DenseSet<Value>` to dedupe for a related problem, but the defensive measure was never applied to two `gpu.wait` patterns.

**Preferred fix:** Don't blindly emit `mgpuStreamSynchronize`/`mgpuStreamDestroy` pairs for *every* `gpu.wait`. We could try tracking streams with a `DenseSet` like the existing `async.yield` code, but it may not catch everything (e.g., two separate `gpu.wait`s with aliasing operands, which incidentally is also emitted by `SparseGPUCodegen`). Might need state that survives across `matchAndRewrite` invocations.

## [mlir] sparsifier rejects `i1` element type in sparse tensor storage

**Problem:**
`mlir::sparse_tensor::primaryTypeEncoding` (`mlir/lib/Dialect/SparseTensor/Transforms/Utils/CodegenUtils.cpp:114-138`) recognizes only `f64/f32/f16/bf16/i64/i32/i16/i8` and `complex<f{32,64}>`; any other element type hits `llvm_unreachable("Unknown primary type")`. We trip this on `i1`: a `linalg.generic` whose body is `arith.cmpf` on a sparse-f32 input naturally produces `tensor<...xi1>`, and the downstream `tensor.cast` to the sparse encoding (the typical pattern when the mask inherits its source's nonzero structure) makes the sparsifier try to allocate sparse-i1 storage. The abort lands in `NewCallParams::genBuffers`, invoked from `SparseTensorAllocConverter::matchAndRewrite(bufferization::AllocTensorOp)` during the `SparseTensorConversion` pass. We hit this when doing a nnz norm for graphsage, as it emits a boolean mask for the nonzero and then attempts to reduce across it. Minimal reproducer is a 12-line `.mlir` with a sparse-f32 input, `cmpf une` to dense i1, and a `tensor.cast` to sparse i1.

**Preferred fix:** Support `i1` as a valid `primaryTypeEncoding` enum. This isn't a trivial patch: the runtime support library is templated over the same `MLIR_SPARSETENSOR_FOREVERY_V` value-type enum, so the codegen-side encoding, the ABI helpers (`primaryTypeFunctionSuffix`, `NewCallParams`), and the runtime templates would all need to grow.



## [mlir] 〔unconfirmed〕 `linalg-fuse-elementwise-ops` drops sparse encoding on synthesized reshapes

**Problem:**
When fusing a producer-consumer pair of `linalg.generic` ops whose iteration spaces don't align, the pass synthesizes a `tensor.expand_shape` (or `collapse_shape`) to reshape one side. The synthesized op's result type preserves the source's element type but **drops** `#sparse_tensor.encoding`. Downstream `sparsification-and-bufferization` then sees a dense intermediate where the producer was sparse, materializes a full-size dense buffer, and emits a dense loop nest over it. On GraphSAGE's row-nnz norm — `aten.sum((A != 0).to(f32), dim=1)` on a CSR adjacency — fusion produces a `tensor<NxNxf32, #sparse> → tensor<Nx1xNxf32>` (note: no `#sparse` on the result) and the lowered IR allocates an `Nx1xN` dense memref. With `N = 169343` (ogbn-arxiv) that's ~115 GB.

**Preferred fix:**
Have the elementwise fusion pass propagate `#sparse_tensor.encoding` from a sparse-encoded source to the result type of any reshape op it synthesizes during fusion.

**Status: unconfirmed.** Verified via local pass-by-pass IR diff that the pre-fuse linalg-on-tensors IR has zero such dense reshapes on sparse operands, and post-fuse has two. Have not confirmed via upstream issue tracker or discourse whether the omission is an unintentional gap or a deliberate choice (sparse-encoding-aware reshape math may have correctness concerns the fusion pass declines to handle). Investigate before submitting as a bug.

----

Lighthouse: YAML files were hard to work with, honestly. I needed pre-legalization rewrite passes and custom passes written using Python bindings, both of which were not possible. Having the behavior depend on file extensions really messed up extensibility, too, since *all* Python files were
