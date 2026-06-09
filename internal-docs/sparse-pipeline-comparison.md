# Sparse-tensor lowering pipeline: gnnc vs references

Reference for what each pass in [gnnc/schedule/sparse.py](../gnnc/schedule/sparse.py) is *for*, what we omit relative to other pipelines and why, and what each external pipeline does that we don't. Built up from a side-by-side investigation in June 2026 after a SAGE-ogbn-arxiv hang traced back to encoding loss across `linalg-fuse-elementwise-ops`. Update this doc when our pipeline changes; the cost of re-deriving "why is `refback-munge-memref-copy` not here" without it is significant.

## TL;DR

- **Shape**: gnnc decomposes the upstream `sparsifier` meta-pass (`buildSparsifier`) into explicit stages so we can inject and reorder. The inner `sparsification-and-bufferization` stays monolithic — its `enable-runtime-library` knob is *not* textually exposed, so we inherit the no-options default (`false` = inline codegen, not runtime library). That matches the canonical direction upstream and dodges the SAGE i1-storage abort the runtime-library path hits.
- **One non-obvious reorder**: `pre-sparsification-rewrite` is hoisted *outside* the inner pass, before `linalg-fuse-elementwise-ops`. Required so `FuseTensorCast` folds dense→sparse casts into producer `linalg.generic`s before elementwise fusion locks them in. MPACT does the same; the meta-pass does not. This hoist is the difference between SAGE compiling and not.
- **Skipped families** (with grep-checklist rationale in each entry): all `refback-*` passes (we use Lighthouse's `MLIRBackend`, not RefBackend), all `tm-tensor-*` passes (torch-mlir decomposes them before our pipeline), MPACT's post-sparse bufferization chain (the inner pass already covers our ops), `convert-shape-to-std` / `refback-mlprogram-bufferize` (zero hits in our IR dumps), and vectorization / `sparse-iterator` (available as `_VL` / `_SPARSE_ITERATOR` knobs, off by default).
- **Reasons to revisit**: a model emitting `tensor.pad` / `tensor.concat` / `tm_tensor.*` / `ml_program.*` / `shape.*` ops, or a future op the inner pass deny-lists (would need a second `one-shot-bufferize` mop-up). Per-pass entries flag the exact grep that confirms current absence.
- **Tag glossary** for the per-pass entries below: `gnnc` = our pipeline, `meta` = `--sparsifier` (`buildSparsifier`), `lit` = upstream CPU integration tests, `mpact` = MPACT's `mpactbackend.py`.

## The reference pipelines

| Tag | Source |
|---|---|
| `gnnc` | [gnnc/schedule/sparse.py](../gnnc/schedule/sparse.py), `build_pipeline` |
| `meta` | `--sparsifier` pass pipeline: [SparseTensorPipelines.cpp:26-101](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Pipelines/SparseTensorPipelines.cpp#L26-L101) (`buildSparsifier`) |
| `lit` | MLIR upstream CPU integration tests, e.g. [sparse_loose.mlir](../third_party/llvm-project/mlir/test/Integration/Dialect/SparseTensor/CPU/sparse_loose.mlir) — almost all invoke the meta-pass directly with options |
| `mpact` | MPACT's CPU lowering, [mpactbackend.py:202-265](/tmp/mpact-compiler/python/mpact/mpactbackend.py#L202-L265) (clone at `/tmp/mpact-compiler`) |

## Side-by-side pass list

Single-screen view of all passes across the four pipelines. Rows ordered roughly by gnnc/meta flow; the MPACT-only block (rows 11-20) is where MPACT's RefBackend tail sits between sparsifier and lowering. Cells: `Y` = runs it, `—` = doesn't, qualifiers in parens. `lit` mirrors `meta` since it invokes the meta-pass with options — kept as a column to make the asymmetry between test fixtures and our pipeline visible. Per-row rationale in [Pass-by-pass](#pass-by-pass) below.

| # | Pass | gnnc | meta | lit | mpact |
|---|---|---|---|---|---|
| 1 | `llvm-request-c-wrappers` | Y | — | — | — |
| 2 | `sparse-assembler{direct-out}` | Y (sparse-only) | — | — | Y |
| 3 | `linalg-generalize-named-ops` | Y | Y | Y | Y |
| 4 | `pre-sparsification-rewrite` (hoisted) | Y | — | — | Y |
| 5 | `linalg-fuse-elementwise-ops` | Y | Y | Y | Y |
| 6 | `convert-shape-to-std` | — | — | — | Y |
| 7 | `sparse-encoding-propagation` | — | — | — | Y (no-op) |
| 8 | `sparsification-and-bufferization{…}` | Y | Y (inner) | Y (inner) | Y |
| 9 | `sparse-storage-specifier-to-llvm` | Y | Y | Y | Y |
| 10 | `canonicalize` (post-sparse) | Y | Y | Y | — |
| 11 | `refback-generalize-tensor-pad/-concat` | — | — | — | Y |
| 12 | `tm-tensor-bufferize` | — | — | — | Y |
| 13 | `one-shot-bufferize` (standalone) | — | — | — | Y |
| 14 | `refback-mlprogram-bufferize` | — | — | — | Y |
| 15 | `finalizing-bufferize` | — | — | — | Y |
| 16 | `buffer-deallocation` | — | Y (ownership) | Y (ownership) | Y (legacy) |
| 17 | `inline` | — | — | — | Y |
| 18 | `refback-munge-calling-conventions` | — | — | — | Y |
| 19 | `tm-tensor-to-loops` | — | — | — | Y |
| 20 | `refback-munge-memref-copy` | — | — | — | Y |
| 21 | `convert-linalg-to-loops` | Y | Y | Y | Y |
| 22 | `refback-expand-ops-for-llvm` | — | — | — | Y |
| 23 | `convert-vector-to-scf` | Y | Y | Y | Y |
| 24 | `expand-realloc` | Y | Y | Y | Y (earlier) |
| 25 | `convert-scf-to-cf` | Y | Y | Y | Y |
| 26 | `expand-strided-metadata` | Y | Y | Y | Y |
| 27 | `lower-affine` | Y | Y | Y | Y |
| 28 | `convert-vector-to-llvm{…}` (×2) | Y | Y | Y | Y (+x86) |
| 29 | scalar lowering (`arith-expand`, `math-to-{llvm,libm}`, `complex-to-{standard,libm}`) | Y | Y | Y | subset |
| 30 | GPU finalize tail (`nvvm-attach-target`, `gpu-to-llvm`, `gpu-module-to-binary`) | Y (gpu) | Y (gpu) | Y (gpu) | — |
| 31 | `convert-to-llvm` | Y | Y | Y | individual |
| 32 | `reconcile-unrealized-casts` | Y | Y | Y | Y |

## Common ground

All four pipelines share a backbone of roughly: torch-mlir / aten-dialect ingress → linalg-on-tensors → some-form-of-sparsifier → bufferize → lower-to-LLVM. The differences are in (a) the form of sparsifier invocation (meta-pass vs decomposed), (b) what mop-up bufferization runs after the sparsifier, (c) which torch-mlir-frontend-specific passes are present, and (d) what knobs (vectorization, runtime-library, emit strategy) are set.

## Pass-by-pass

Each entry: what the pass does, who runs it, why we do or don't.

### `func.func(llvm-request-c-wrappers)`

Annotates exported `func.func`s with the `llvm.emit_c_interface` attribute so torch-mlir / Lighthouse JIT can find an unmangled entry point.

- **gnnc**: yes, first pass — applies before any sparse processing so the entry symbol survives all rewrites.
- **meta / lit**: no — the meta-pass doesn't add the wrapper attribute; consumers do it externally before invoking `--sparsifier`.
- **mpact**: no — MPACT lowers through RefBackend which uses its own calling convention (`refback-munge-calling-conventions`).
- **Reason for us**: Lighthouse's JIT depends on `llvm.emit_c_interface` to call the entry function from C-side runtime glue.

### `sparse-assembler{direct-out}`

Inserts `sparse_tensor.assemble` / `disassemble` ops at the function boundary so callers pass in COO-style decomposed tensors (positions + coordinates + values) rather than opaque sparse tensors. `direct-out=true` keeps the assembled result in the function's output slot (skips an extra copy).

- **gnnc**: yes, only when `has_sparse=True`.
- **meta**: no, not part of `buildSparsifier`. Sample programs that go through the meta-pass typically add it themselves before invoking.
- **lit**: no — upstream test programs are written with sparse semantics already at the function boundary, so they don't need the assembler insertion.
- **mpact**: yes (line 220) — same role for the torch-frontend convention.
- **Reason for us**: torch-mlir hands us tensors with `#sparse_tensor.encoding` on the boundary; sparse-assembler converts that to the COO-decomposed external ABI Lighthouse's runtime expects.

### `func.func(linalg-generalize-named-ops)`

Converts named `linalg.matmul` / `linalg.batch_matmul` / etc. to `linalg.generic` form so subsequent passes can match on the generic shape rather than each named variant.

- **gnnc**: yes.
- **meta**: yes ([line 29](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Pipelines/SparseTensorPipelines.cpp#L29)).
- **mpact**: yes.
- **Reason for us**: same as upstream — the sparsifier patterns are written against generic form.

### `pre-sparsification-rewrite`

A bundle of patterns ([SparseTensorRewriting.cpp:1607](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Transforms/SparseTensorRewriting.cpp#L1607)): `FuseExtractSliceWithConcat`, `FoldConvertIntoProducer`, `FoldInvariantYield`, `FuseSparseMultiplyOverAdd`, `FuseTensorCast`, `GenSemiRingReduction`, `GenSemiRingSelect`, `PrintRewriter`. The load-bearing one for downstream torch-mlir patterns is `FuseTensorCast`, which folds a `tensor.cast` (dense→sparse-encoded) into its producer `linalg.generic` so the producer emits sparse-encoded output directly. Without it, the dense intermediate flows into the sparsifier and gets allocated as dense.

- **gnnc**: yes, **hoisted to outer level** before `linalg-fuse-elementwise-ops`. The inner `sparsification-and-bufferization` also runs it ([line 135](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Transforms/SparsificationAndBufferizationPass.cpp#L135)), but by then elementwise fusion has already locked in the dense intermediate — too late.
- **meta**: no at outer level — only the inner one. This is the "outer-only" hoist we discovered we needed.
- **mpact**: yes, hoisted ([line 209](/tmp/mpact-compiler/python/mpact/mpactbackend.py#L209)), with the comment "Run pre-sparsification pass to fuse convert/cast op into producer as they might hinder kernel fusions." Same motivation.
- **Reason for us**: GraphSAGE's `_sparse_mm.reduce` decomposition produces `cmpf` + `tensor.cast` patterns; without hoisting, fusion runs first and the cast can't be folded.

### `func.func(linalg-fuse-elementwise-ops)`

Fuses adjacent elementwise `linalg.generic` ops to reduce intermediate buffers.

- **gnnc**: yes.
- **meta**: yes ([line 30](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Pipelines/SparseTensorPipelines.cpp#L30)).
- **mpact**: yes.
- **Reason for us**: same as upstream. **Caveat — known bug**: this pass synthesizes `tensor.expand_shape` / `tensor.collapse_shape` when fusing producer-consumer pairs with mismatched iteration spaces, and the synthesized reshapes drop `#sparse_tensor.encoding` from the input type. Tracked in [upstream-wishlist.md](upstream-wishlist.md) as unconfirmed. A reshape-encoding invariant assertion exists in [sequester/assert_sparse_invariants/](../sequester/assert_sparse_invariants/) but is not currently wired into the pipeline.

### `convert-shape-to-std`

Lowers `shape.*` ops to scalar `arith` / `index` ops.

- **gnnc**: no.
- **meta / lit**: no.
- **mpact**: yes (line 211).
- **Reason we skip**: torch-mlir's linalg-on-tensors backend doesn't emit `shape.*` ops in our path. Confirmed: `grep "shape\." /tmp/ir-inspect/*.linalg.mlir` returns 0. Could matter if a future model uses dynamic shape ops; revisit if needed.

### `func.func(sparse-encoding-propagation)`

Slot for propagating `#sparse_tensor.encoding` through ops that don't naturally preserve it. **MPACT-internal C++ pass** ([SparseEncodingPropagate.cpp:30](/tmp/mpact-compiler/lib/Transforms/Sparsity/SparseEncodingPropagate.cpp#L30)) — **the body is empty** (`runOnOperation()` is a stub). Not a registered MLIR upstream pass.

- **gnnc**: no.
- **meta / lit**: no.
- **mpact**: yes (line 215) but no-op.
- **Reason we skip**: even if we wanted it, it's not textually registered upstream, so we'd have to either link MPACT or rewrite the equivalent in Python. And MPACT's version doesn't actually do anything. Our reshape-encoding-preserve invariant pass occupies this conceptual slot.

### `sparsification-and-bufferization{...options}`

The monolithic inner sparsifier mini-pipeline. Runs `pre-sparsification-rewrite` internally, then bufferization analysis, then sparsification + sparse codegen. Reads `enable-runtime-library` from constructor args (NOT textually settable on this pass — only on the meta-pass).

- **gnnc**: yes. CPU: `parallelization-strategy=dense-outer-loop` only when `target == "gpu"`, plus optional `vl=N enable-simd-index32` (off by default) and `sparse-emit-strategy=sparse-iterator` (off by default). `enable-runtime-library` defaults to `false` (the no-options textual default) which means inline codegen, NOT the runtime-library path.
- **meta**: yes, wrapped in `--sparsifier` which exposes `enable-runtime-library` as an option defaulting to `true`.
- **lit**: invoked via `--sparsifier="enable-runtime-library=true"` (most tests) or `"=false"` (codegen-coverage tests).
- **mpact**: yes, with `vl=16 enable-simd-index32` (AVX-512) OR `sparse-emit-strategy=sparse-iterator` based on a `use_sp_it` flag.
- **Asymmetry note**: meta-pass default is `enable-runtime-library=true`, decomposed default is `false`. The runtime-library path links into `libmlir_c_runner_utils.so` symbols; the codegen path emits everything inline. Aart Bik's direction for the dialect has been toward the codegen path; the runtime path is on the deprecation curve but still the default in upstream-test fixtures.
- **Why we use no options on CPU**: matches the codegen-path tests in upstream and avoids the i1-storage `llvm_unreachable` ([upstream-wishlist.md](upstream-wishlist.md) item 4) that the runtime-library path hits on SAGE.

### `sparse-storage-specifier-to-llvm`

Lowers sparse-tensor storage-specifier ops (per-level metadata: positions, coordinates, values) to LLVM-compatible struct loads/stores.

- **gnnc**: yes.
- **meta**: yes ([line 50](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Pipelines/SparseTensorPipelines.cpp#L50)).
- **mpact**: yes (line 222).
- **Reason for us**: needs to happen before the LLVM lowering tail; standard.

### `func.func(canonicalize)`

Canonical canonicalization.

- **gnnc**: yes, post-sparsifier.
- **meta**: yes ([line 51](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Pipelines/SparseTensorPipelines.cpp#L51)).
- **mpact**: no — relies on the inner pass's canonicalization.
- **Reason for us**: matches meta-pass; cleans up the sparsifier's output before lowering.

### `func.func(expand-realloc)`

Lowers `memref.realloc` into its components.

- **gnnc**: yes, late in the lowering tail (so realloc ops generated by inner bufferization are expanded before LLVM lowering sees them).
- **meta**: yes ([line 69](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Pipelines/SparseTensorPipelines.cpp#L69)) under the name `memref-expand-realloc` (the textual pass name is `expand-realloc`; the guide had this wrong).
- **mpact**: yes (line 224), runs *before* their bufferization chain ("Buffer deallocation pass does not know how to handle realloc" per their comment).
- **Reason for us**: at our position it's adjacent to the rest of the LLVM-side tail; works.

### `refback-generalize-tensor-pad` / `refback-generalize-tensor-concat`

Lower `tensor.pad` and `tensor.concat` to `linalg.generic` so the sparsifier and bufferization can reason about them.

- **gnnc**: no.
- **meta**: no.
- **mpact**: yes (lines 227-228).
- **Reason we skip**: `grep "tensor.pad\|tensor.concat" /tmp/ir-inspect/*.linalg.mlir` returns 0 across GCN and SAGE on both cora and ogbn-arxiv. **Add when a model emits these** — likely with conv ops or shape-concatenation patterns.

### `func.func(tm-tensor-bufferize)`

Bufferizes `tm_tensor.*` ops (torch-mlir's TMTensor dialect — sort, scan, scatter, attention) via legacy `DialectConversion`. TMTensor ops do **not** implement `BufferizableOpInterface` — this is the only path that bufferizes them.

- **gnnc**: no.
- **meta / lit**: no.
- **mpact**: yes (line 230).
- **Reason we skip**: torch-mlir's `torch-backend-to-linalg-on-tensors-backend-pipeline` (invoked inside [compile.py:56](../gnnc/compile.py#L56)) decomposes TMTensor ops to plain linalg before our pipeline begins. `grep "tm_tensor" /tmp/ir-inspect/*.mlir` returns 0 across all dumps.

### `one-shot-bufferize{copy-before-write bufferize-function-boundaries function-boundary-type-conversion=identity-layout-map}`

The modern bufferization pass. Whole-function alias analysis on tensor SSA chains, decides per-op whether to bufferize in-place or insert a copy, then rewrites tensor IR to memref IR. Two-phase: analyze all, rewrite all. Hinges on destination-passing-style ops (`DestinationStyleOpInterface`) for alias anchors.

- **gnnc**: no, as a separate pass. The inner `sparsification-and-bufferization` runs One-Shot Bufferize *internally* on whatever isn't sparse-relevant ([SparsificationAndBufferizationPass.cpp:154](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Transforms/SparsificationAndBufferizationPass.cpp#L154)).
- **meta / lit**: no, same reason — inner pass handles it.
- **mpact**: yes (line 231). MPACT runs a *second* one-shot bufferize *after* the sparsifier-and-bufferization to mop up tensor ops the inner pass deny-listed (e.g. ops touching ml_program or torch-specific tensors).
- **Reason we skip**: our IR has 0 tm_tensor / ml_program ops; the inner one-shot inside `sparsification-and-bufferization` covers everything else (linalg, tensor, scf, arith, vector — all have `BufferizableOpInterface` impls upstream). **Reconsider** if we ever land an op in our IR that the inner pass deny-lists.

### `refback-mlprogram-bufferize`

Bufferizes `ml_program.global` and related globals.

- **gnnc**: no.
- **meta / lit**: no.
- **mpact**: yes (line 232).
- **Reason we skip**: `grep "ml_program" /tmp/ir-inspect/*.mlir` returns 0 across our IR dumps.

### `func.func(finalizing-bufferize)`

Resolves residual bridging ops left after bufferization: `bufferization.to_memref`, `bufferization.to_tensor`, `bufferization.materialize_in_destination`.

- **gnnc**: no.
- **meta**: no (relies on inner one-shot to finish cleanly).
- **mpact**: yes (line 233).
- **Reason we skip**: inner pass's one-shot leaves no bridging ops in our paths. **Reconsider** if a future pass introduces them.

### `func.func(buffer-deallocation)`

Inserts `memref.dealloc` for buffers allocated during bufferization.

- **gnnc**: no.
- **meta**: yes — runs `ownership-based-buffer-deallocation` internally as part of the inner pass.
- **mpact**: yes (line 234), legacy form.
- **Reason we skip**: inner pass handles ownership-based deallocation; the legacy `buffer-deallocation` is upstream-deprecated.

### `inline`

Generic inliner.

- **gnnc**: no.
- **meta / lit**: no.
- **mpact**: yes (line 236), with the comment "Inline sparse helper methods where useful (but after dealloc)."
- **Reason we skip**: our sparsifier doesn't emit out-of-line sparse helper functions in the codegen path. **Reconsider** if codegen output ever has helper functions worth inlining.

### `refback-munge-calling-conventions`

Adjusts function signatures so RefBackend's JIT can call them (specific to torch-mlir's RefBackend ABI).

- **gnnc**: no.
- **mpact**: yes (line 237).
- **Reason we skip**: we use Lighthouse's `MLIRBackend`, not RefBackend. Different ABI assumption.

### `func.func(tm-tensor-to-loops)`

Lowers any remaining `tm_tensor.*` ops to `scf.for` loops + plain linalg ops.

- **gnnc**: no.
- **mpact**: yes (line 238).
- **Reason we skip**: no `tm_tensor.*` ops in our IR (decomposed by torch-mlir's linalg-on-tensors backend before our pipeline begins).

### `func.func(refback-munge-memref-copy)`

Rewrites `memref.copy` into a `linalg.generic` identity-copy.

- **gnnc**: no.
- **mpact**: yes (line 239) because MPACT's RefBackend JIT setup doesn't link `libmlir_runner_utils.so` (which provides `memrefCopy` runtime symbol).
- **Reason we skip**: Lighthouse's `Runner` auto-adds `libmlir_c_runner_utils.so` ([runner.py:58-60](../third_party/lighthouse/lighthouse/execution/runner.py#L58-L60)) which has the `memrefCopy` symbol. `memref.copy` resolves natively for us at JIT time.

### `func.func(convert-linalg-to-loops)`

Lowers any remaining `linalg.generic` to `scf.for` loops.

- **gnnc**: yes.
- **meta**: yes ([line 67](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Pipelines/SparseTensorPipelines.cpp#L67)).
- **mpact**: yes (line 240).
- **Reason for us**: standard tail-of-sparsifier lowering.

### `func.func(convert-vector-to-scf)` / `convert-scf-to-cf` / `lower-affine` / `expand-strided-metadata`

Standard SSA-level lowering: vector ops to scf loops, scf to control-flow blocks, affine to arith, memref-strided to arith.

- **gnnc / meta / mpact**: all run these. Order matches upstream.

### `func.func(refback-expand-ops-for-llvm)`

Expands `math.tanh` and `math.erf` to polynomial approximations.

- **gnnc**: no.
- **mpact**: yes (line 243).
- **Reason we skip**: we run `convert-math-to-libm` which routes `math.tanh` / `math.erf` to libm function calls. MPACT inlines polynomial approximations (no libm dependency, no call overhead, but different precision); we use libm (more precise, slight per-element call cost, depends on libm being linked, which Lighthouse Runner handles).

### `arith-expand` / `convert-math-to-llvm` / `convert-math-to-libm` / `convert-complex-to-standard` / `convert-complex-to-libm`

Standard scalar lowering.

- **gnnc**: yes (most as `func.func(...)`-nested).
- **meta**: yes (matches buildSparsifier tail).
- **mpact**: yes (subset; uses `convert-arith-to-llvm` separately).

### `convert-vector-to-llvm{options}`

Lowers vector ops to LLVM intrinsics.

- **gnnc**: yes, no options — relies on the pass's own defaults: `force-32bit-vector-indices=true` (matches SparsifierOptions), `reassociate-fp-reductions=false`.
- **meta**: yes, with `SparsifierOptions`-driven options threaded through the meta-pass: `force32BitVectorIndices=true`, `reassociateFPReductions=false`, plus arch-specific (`armNeon`, `armSVE`, `x86` all default false).
- **mpact**: yes, with explicit `reassociate-fp-reductions force-32bit-vector-indices enable-x86vector` — they enable the SparsifierOptions defaults *and* x86 vector dialect.
- **Reason we use default options**: matches SparsifierOptions defaults effectively. Setting `enable-x86vector` would be a target-specific opt-in that we could expose as a knob later.

### `nvvm-attach-target{triple=... chip=... features=...}` / `gpu-to-llvm` / `gpu-module-to-binary{format=fatbin}`

GPU finalization tail; only runs when `target == "gpu"`.

- **gnnc**: yes.
- **meta**: yes when `gpuTriple` is set, with `SparsifierOptions`-driven `triple` / `chip` / `features` / `format`.
- **mpact**: no — MPACT is CPU-only.

### `convert-to-llvm`

Umbrella pass that runs the func / arith / cf / index / control-flow / complex lowering to LLVM all at once.

- **gnnc**: yes, single pass.
- **meta**: yes ([line 97](../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Pipelines/SparseTensorPipelines.cpp#L97)).
- **mpact**: no, runs the constituent passes individually (`convert-func-to-llvm`, `convert-cf-to-llvm`, `convert-complex-to-llvm`, etc).
- **Reason for us**: same as meta-pass; less verbose and equivalent.

### `reconcile-unrealized-casts`

Resolves `unrealized_conversion_cast` ops left between dialects after lowering.

- **gnnc / meta / mpact**: all run this last.

## Recap of structural decisions

- **We decomposed the meta-pass** (`buildSparsifier`) into its constituent passes per Q1 ("outer-only"). The trade-off is we lost the `enable-runtime-library` knob (only textually settable on `--sparsifier`) and inherit the codegen-path defaults for the inner pass. Acceptable because the codegen path is the canonical direction and the runtime-library path hits a sparser i1 abort on SAGE (wishlist item 4).
- **We hoisted `pre-sparsification-rewrite` outside the inner pass.** MPACT also does this; meta-pass does not. The hoist is required for `FuseTensorCast` to operate on torch-mlir-frontend-emitted `tensor.cast` patterns before `linalg-fuse-elementwise-ops` locks them in.
- **We skip MPACT's post-sparse bufferization chain** (`one-shot-bufferize`, `finalizing-bufferize`, `buffer-deallocation`, `convert-bufferization-to-memref`). The inner pass's One-Shot covers everything we have. Reconsider if a future op slips past the inner pass as un-bufferized tensor IR.
- **We skip all `refback-*` and `tm-tensor-*` passes.** They're for ops we don't have in our IR (or that we route through different mechanisms — libm vs polynomial expansion, c_runner_utils vs munge-memref-copy).
- **We don't run vectorization or sparse-iterator by default.** Both available as knobs (`_VL`, `_SPARSE_ITERATOR` in [schedule/sparse.py](../gnnc/schedule/sparse.py)) but require target-knowledge before flipping on.
