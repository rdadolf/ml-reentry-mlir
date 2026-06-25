// Renames `func.func @bar` to `@foo` (the example C++ pass), exercised two ways
// that must produce identical IR and so share one set of CHECK lines:
//   1. through the `mlir-opt` pass plugin (the C++ plugin front end), and
//   2. in-process through `gnnc-opt` (the Python pipeline), which resolves the
//      same pass via the gnnc._gnncRegisterPasses module.
//
// The pass is anchored on `func.func`, so it is nested under that op. gnnc-opt's
// pass stage already roots at `builtin.module`, so its `--pass` value omits the
// outer `builtin.module(...)` the plugin pipeline spells explicitly.
//
// RUN: mlir-opt %s --load-pass-plugin=%gnnc_plugin \
// RUN:   --pass-pipeline="builtin.module(func.func(gnnc-switch-bar-foo))" | FileCheck %s
// RUN: gnnc-opt %s --pass 'func.func(gnnc-switch-bar-foo)' | FileCheck %s

// CHECK-LABEL: func.func @foo
// CHECK-NOT:   func.func @bar
func.func @bar() {
  return
}

// CHECK-LABEL: func.func @baz
func.func @baz() {
  return
}
