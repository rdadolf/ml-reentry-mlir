// REQUIRES: gnnc-plugin
// RUN: mlir-opt %s --load-pass-plugin=%gnnc_plugin \
// RUN:   --pass-pipeline="builtin.module(func.func(gnnc-switch-bar-foo))" | FileCheck %s
//
// Dummy C++ pass loaded as a plugin: renames @bar -> @foo per func.

// CHECK-LABEL: func.func @foo
// CHECK-NOT:   func.func @bar
func.func @bar() {
  return
}

// CHECK-LABEL: func.func @baz
func.func @baz() {
  return
}
