//===- Passes.td - gnnc transform passes -------------------*- tablegen -*-===//
//
// TableGen declarations for gnnc's C++ MLIR passes. `mlir_tablegen
// --gen-pass-decls -name GNNC` turns each `def` here into a `*Base<T>` CRTP
// class, registration glue, and an options struct. One `def` per pass.
//
//===----------------------------------------------------------------------===//

#ifndef GNNC_TRANSFORMS_PASSES
#define GNNC_TRANSFORMS_PASSES

include "mlir/Pass/PassBase.td"

def GNNCSwitchBarFoo : Pass<"gnnc-switch-bar-foo", "mlir::func::FuncOp"> {
  let summary = "Rename a `func.func` named `bar` to `foo` (example pass).";
  let description = [{
    A minimal example pass used to validate the out-of-tree C++ build and
    name-based registration. Runs once per `func.func`; if the function is
    named `bar`, renames it to `foo`.

    ```mlir
    func.func @bar() { return }
    // becomes
    func.func @foo() { return }
    ```

    Real passes replace this. The pass is addressable as `gnnc-switch-bar-foo`
    from both `mlir-opt --load-pass-plugin` and the Python pipeline once the
    C++ plugin is loaded.
  }];
}

#endif // GNNC_TRANSFORMS_PASSES
