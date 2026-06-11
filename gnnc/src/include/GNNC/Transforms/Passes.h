//===- Passes.h - gnnc transform passes -------------------------*- C++ -*-===//
//
// Public header for gnnc's C++ passes. Pulls in the TableGen-generated pass
// declarations and the `registerGNNCPasses()` entry point that registers all
// of them with the global `PassRegistry`.
//
//===----------------------------------------------------------------------===//

#ifndef GNNC_TRANSFORMS_PASSES_H
#define GNNC_TRANSFORMS_PASSES_H

#include "mlir/Pass/Pass.h"
#include <memory>

namespace gnnc {
#define GEN_PASS_DECL
#include "GNNC/Transforms/Passes.h.inc"

// Generates `registerGNNCPasses()` (and per-pass `register*()` helpers).
#define GEN_PASS_REGISTRATION
#include "GNNC/Transforms/Passes.h.inc"
} // namespace gnnc

#endif // GNNC_TRANSFORMS_PASSES_H
