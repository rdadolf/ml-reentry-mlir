# Custom MLIR LSP server

Editor support (hover, go-to-definition, find-references) for `.mlir`
files goes through `mlir-lsp-server`-class binaries. None of the ones
shipped by upstream MLIR or torch-mlir cover every dialect we touch.

## The problem

MLIR dialect registration is compile-time linkage, not dynamic loading or
config-driven discovery. Each LSP-server binary's `main()` explicitly
constructs a `DialectRegistry` and registers a fixed set; anything not in
that set is reported as "Dialect not found" and the **whole file fails to
parse** (no `--allow-unregistered-dialect` flag is exposed on the LSP
binaries). With no AST, hover/goto/refs return nothing for *any* op in
the file, even those from registered dialects.

Concrete instances of the gap, as of this writing:

- `mlir-lsp-server` (stock) registers upstream dialects (`arith`,
  `linalg`, `tensor`, `affine`, `scf`, …) but not `torch.*`, `tm_tensor`,
  `torch_c`. Parses test-input MLIR fine; fails on anything from
  torch-mlir's importer output.
- `torch-mlir-lsp-server` registers the torch family plus a curated subset
  of upstream needed by torch lowering (no `arith`, no `affine`, no
  `math`, no `vector`, …). Parses raw torch-dialect dumps fine; fails on
  any post-lowering output (e.g., the `*.2-linalg.mlir` dumps that contain
  `arith.constant`).
- Future: neither will know our `gnn.*` dialect.

No combination of existing binaries + extension settings closes this gap.

## The solution

A project-local `gnnc-lsp-server` binary. The C++ is trivial — torch-mlir's
own LSP server is **22 lines** including license header; ours is the same
skeleton with one more registration call:

```cpp
#include "mlir/InitAllDialects.h"
#include "mlir/Tools/mlir-lsp-server/MlirLspServerMain.h"
#include "torch-mlir/InitAll.h"
// #include "gnnc/Dialect/GNN/IR/GNNDialect.h"   // when we have one

int main(int argc, char **argv) {
  mlir::DialectRegistry registry;
  mlir::registerAllDialects(registry);                  // upstream
  mlir::torch::registerAllDialects(registry);           // torch family
  mlir::torch::registerOptionalInputDialects(registry); // torch input dialects
  // mlir::gnn::registerDialect(registry);              // ours
  return mlir::failed(mlir::MlirLspServerMain(argc, argv, registry));
}
```

The actual work is the **build integration**, not the C++. The CMake
target needs to link `MLIRLspServerLib`, the upstream dialect/conversion/
extension libs, `TorchMLIRInitAll`, and (later) the `gnn` dialect lib.
Pattern to copy:

- [third_party/torch-mlir/tools/torch-mlir-lsp-server/torch-mlir-lsp-server.cpp](../third_party/torch-mlir/tools/torch-mlir-lsp-server/torch-mlir-lsp-server.cpp) — minimal `main`
- [third_party/torch-mlir/tools/torch-mlir-lsp-server/CMakeLists.txt](../third_party/torch-mlir/tools/torch-mlir-lsp-server/CMakeLists.txt) — `add_llvm_executable` + link libs
- [third_party/llvm-project/mlir/tools/mlir-lsp-server/mlir-lsp-server.cpp](../third_party/llvm-project/mlir/tools/mlir-lsp-server/mlir-lsp-server.cpp) — fuller example, includes the upstream dialect-collection pattern

The build needs to find LLVM/MLIR CMake exports (already on disk via
[tools/build-llvm.sh](../tools/build-llvm.sh)'s output) and torch-mlir's
(via [tools/build-torch-mlir.sh](../tools/build-torch-mlir.sh)). Likely
this lives as a new top-level CMake target alongside the future `gnnc-opt`
binary; it doesn't need to be part of the LLVM out-of-tree build.

Then in [.vscode/settings.json](../.vscode/settings.json) flip
`mlir.server_path` from the torch-mlir binary to the new one.

## When to do this

Not now. Editor ergonomics matter when we're authoring non-trivial MLIR
by hand. Right now `.mlir` files are mostly *read* (dumps as artifacts)
or are short hand-written lit-test inputs that stay within a single
registered dialect family. The `problems.visibility: false` setting hides
the spurious squiggles until we care.

Pull this off the back burner when one of these is true:

- We're writing the `gnn.*` dialect and want hover/goto on its ops.
- We're hand-authoring more than ~50 lines of post-lowering MLIR per week
  for tests or experiments.
- The lack of cross-op navigation is actively slowing debugging.
