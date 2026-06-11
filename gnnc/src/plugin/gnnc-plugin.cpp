//===- gnnc-plugin.cpp - gnnc pass plugin -----------------------*- C++ -*-===//
//
// Exposes gnnc's C++ passes as an `mlir-opt` pass plugin so individual passes
// can be lit-tested in isolation. A plugin-loaded pass is not exposed as a bare
// `--pass-name` flag (the plugin loads while the CLI is parsed, after those
// flags are built), so it's driven through --pass-pipeline:
//
//   mlir-opt %s --load-pass-plugin=.../GNNCPlugin.so \
//     --pass-pipeline="builtin.module(func.func(gnnc-switch-bar-foo))"
//
// The pipeline itself loads the same passes in-process (a Python extension
// module calls `registerGNNCPasses()` on import); this plugin is the
// CLI/testing front end for that same registration entry point.
//
//===----------------------------------------------------------------------===//

#include "GNNC/Transforms/Passes.h"
#include "mlir/Tools/Plugins/PassPlugin.h"
#include "llvm/Config/llvm-config.h"
#include "llvm/Support/Compiler.h"

extern "C" LLVM_ATTRIBUTE_WEAK mlir::PassPluginLibraryInfo
mlirGetPassPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "GNNCPasses", LLVM_VERSION_STRING,
          []() { ::gnnc::registerGNNCPasses(); }};
}
