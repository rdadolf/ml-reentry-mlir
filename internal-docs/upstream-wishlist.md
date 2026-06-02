# Upstream Fix/Feature Wishlist

### [torch-mlir] MLIR-style type properties for `vtensor`/`tensor`

**Problem:**
torch-mlir binds its dialect ops to Python but not its types — no `VTensorType.get(...)` factory, no `.shape` / `.element_type` / `.encoding` accessors, no `.isinstance(t)`. The C API in `torch-mlir-c/TorchTypes.h` is complete; only the Python pybind/nanobind layer is missing. Downstream Python users fall back to text round-trip on `str(t)` (see `gnnc/transform/rewrites/util.py` for what the workaround looks like).

**Preferred fix:**
Add nanobind bindings for `ValueTensorType`, `NonValueTensorType`, container types (`ListType`, `OptionalType`, `TupleType`, …), and primitive types — modeled on upstream MLIR's `mlir/lib/Bindings/Python/IRTypes.cpp` (specifically `PyRankedTensorType`). One C API gap to close first: add `torchMlirTorchValueTensorTypeGetSparsity` (and the NonValue parallel) — the current C API has a sparsity constructor argument but no readback.

### [mlir] Python bindings for `notify_match_failure` and `Operation.emit_*`

**Problem:**
The Python `mlir.rewrite.PatternRewriter` exposes only `replace_op`, `erase_op`, and `ip` — no `notify_match_failure(op, msg)`. And `Operation` has no `emit_error` / `emit_warning` / `emit_remark` at all; the only bound emit surface is `Location.emit_error`, which lacks warning/remark counterparts. C++ patterns lean heavily on both: `notifyMatchFailure` for soft bails (logged via `--debug-only=greedy-rewriter`) and `op.emit{Error,Warning,Remark}` for IR-located diagnostics. Python rewrites have no equivalent — they print to stderr, raise, or stay silent.

**Preferred fix:**
Bind `Operation.emit_error/_warning/_remark` and `Location.emit_warning/_remark` (parallel to the existing `Location.emit_error`); add `PatternRewriter.notify_match_failure(op, msg)`. All four C API hooks (`mlirEmitError`, `mlirOperationEmitOpError`, etc.) already exist — this is small nanobind glue, structurally parallel to how the IR types are bound.
