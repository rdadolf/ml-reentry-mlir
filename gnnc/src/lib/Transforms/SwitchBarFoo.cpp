//===- SwitchBarFoo.cpp - Example gnnc pass ---------------------*- C++ -*-===//
//
// Implements `gnnc-switch-bar-foo`, the example pass declared in Passes.td.
// Exists to validate the out-of-tree build + name-based registration; replace
// with real passes.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Func/IR/FuncOps.h"

#include "GNNC/Transforms/Passes.h"

namespace gnnc {
#define GEN_PASS_DEF_GNNCSWITCHBARFOO
#include "GNNC/Transforms/Passes.h.inc"

namespace {
class GNNCSwitchBarFoo : public impl::GNNCSwitchBarFooBase<GNNCSwitchBarFoo> {
public:
  using impl::GNNCSwitchBarFooBase<GNNCSwitchBarFoo>::GNNCSwitchBarFooBase;

  void runOnOperation() final {
    mlir::func::FuncOp func = getOperation();
    if (func.getSymName() == "bar")
      func.setSymName("foo");
  }
};
} // namespace
} // namespace gnnc
