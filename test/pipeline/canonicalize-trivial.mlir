// RUN: mlir-opt %s --canonicalize | FileCheck %s
//
// Smoke test: validates that lit, mlir-opt, and FileCheck are all wired up.
// A trivially-canonicalizable arithmetic op (add of two constants) is folded
// to a single constant.

// CHECK-LABEL: func.func @add_consts
// CHECK:         %[[C7:.+]] = arith.constant 7 : i32
// CHECK:         return %[[C7]] : i32
func.func @add_consts() -> i32 {
  %c3 = arith.constant 3 : i32
  %c4 = arith.constant 4 : i32
  %sum = arith.addi %c3, %c4 : i32
  return %sum : i32
}
