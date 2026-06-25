# Enabling gnnc's custom C++ passes in the Python pipeline

## Goal

Make gnnc's own C++ passes (today only `gnnc-switch-bar-foo`) runnable by name
from the Python pipeline — `gnnc-opt --pass gnnc-switch-bar-foo`, and inside
`gnnc.schedule` phases — the same way upstream passes (`convert-to-llvm`,
`sparse-assembler`, …) already are.

## Current state

- Pass implementations live in the `GNNCTransforms` library
  ([gnnc/src/lib/Transforms](../gnnc/src/lib/Transforms)), declared in
  [Passes.td](../gnnc/src/include/GNNC/Transforms/Passes.td). `registerGNNCPasses()`
  is generated into [Passes.h](../gnnc/src/include/GNNC/Transforms/Passes.h) by
  the `GEN_PASS_REGISTRATION` TableGen hook.
- [GNNCPlugin.so](../gnnc/src/plugin/gnnc-plugin.cpp) wraps that same
  `registerGNNCPasses()` as an `mlir-opt` pass plugin. It is reachable only
  through `mlir-opt --load-pass-plugin`, used by
  [test/transform/switch-bar-foo.mlir](../test/transform/switch-bar-foo.mlir).
- Nothing calls `registerGNNCPasses()` from Python, so the passes are absent
  from the in-process pass registry. Upstream passes are present only because
  Lighthouse registers them when it loads its dialects.

## Mechanism

- MLIR's pass registry is a process-global
  `llvm::ManagedStatic<llvm::StringMap<PassInfo>>`
  ([mlir/lib/Pass/PassRegistry.cpp:27](../third_party/llvm-project/mlir/lib/Pass/PassRegistry.cpp#L27)),
  keyed by each pass's *argument* string (e.g. `gnnc-switch-bar-foo`).
- `registerPass(PassAllocatorFunction)` inserts one entry. `PassAllocatorFunction`
  is `std::function<std::unique_ptr<Pass>()>` — a factory. `GEN_PASS_REGISTRATION`
  emits one `registerPass(...)` per pass `def`, plus the aggregate
  `registerGNNCPasses()`.
- A textual pass pipeline — what `mlir.passmanager.PassManager.parse("…")`
  builds — is resolved against this registry by `parsePassPipeline`
  (`passRegistry->find(arg)`).
- Registration is process-global and one-time; it is not per-`Context`. So the
  single missing action is to call `registerGNNCPasses()` once in the Python
  process, before a `PassManager` parses a gnnc pass name.

## Required work

### 1. In-process registration bridge (the core)

A small Python extension module that links `GNNCTransforms` and calls
`gnnc::registerGNNCPasses()` at import.

- New CMake target alongside [gnnc/src/plugin](../gnnc/src/plugin), using
  **nanobind** — the framework the MLIR Python bindings use (`libnanobind-mlir.so`
  ships in the venv). A module initializer that calls `registerGNNCPasses()` is
  enough; no symbols need to be exposed to Python.
- The extension must link the **same** `libMLIR` instance as the `mlir` Python
  bindings. The global `passRegistry` lives in that library; an extension that
  links a second copy registers into a different registry, and `PassManager.parse`
  will not find the passes. This shared-library constraint is the main risk.
- Built by [tools/build-gnnc.sh](../tools/build-gnnc.sh); symlinked into the
  venv `site-packages` by [tools/link-stack.sh](../tools/link-stack.sh),
  matching how the rest of the stack is linked.

### 2. Load it from the Python tools

- `gnnc-opt` imports the extension before constructing a `PassManager`. Per the
  note in [gnnc/src/plugin/CMakeLists.txt](../gnnc/src/plugin/CMakeLists.txt),
  defer the import until a gnnc pass is actually requested, so pure-upstream
  runs do not pay for it.
- `Phase._materialize` needs no change: once registered, a gnnc C++ pass resolves
  through the existing `Descriptor` → `PassStage` path like any other registered
  pass. Only Python passes use the name→callable registry.
- Name collisions need no new work either. `PyPassRegistry` already probes every
  Python pass name against the C++ registry (`PassManager.parse("any(name)")`),
  so once this bridge registers the gnnc C++ passes in-process, a Python pass
  that shadows one of them is caught automatically.

### 3. Test

Mirror [test/transform/switch-bar-foo.mlir](../test/transform/switch-bar-foo.mlir),
but drive it through `gnnc-opt --pass gnnc-switch-bar-foo` instead of
`mlir-opt --load-pass-plugin`: `@bar` becomes `@foo`. This proves in-process
registration works end to end.

## Alternative considered

Loading `GNNCPlugin.so` into the Python process via an MLIR C-API plugin loader,
rather than a dedicated extension. The Python bindings expose no pass-plugin
loader, and `GNNCPlugin.so` is a `MODULE BUILDTREE_ONLY` artifact built against
`mlir-opt`. The dedicated extension is the supported path; the `.so` plugin stays
the `mlir-opt`/lit front end. Both call the same `registerGNNCPasses()`, so they
do not diverge.

## Open questions for the implementer

- Confirm the MLIR Python bindings link a shared `libMLIR` (not static), so the
  extension can share the global registry. If static, the bridge needs a
  different approach (register through a registry the bindings already expose).
- Confirm the nanobind version/ABI matches the bindings' `libnanobind-mlir.so`.
- Decide where the import happens: lazily in `gnnc-opt` on first gnnc-pass use,
  or eagerly in a `gnnc.passes` package import.
