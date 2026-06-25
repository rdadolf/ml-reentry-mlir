//===- RegisterPasses.cpp - nanobind module registering gnnc passes -------===//
//
// The `_gnncRegisterPasses` module registers gnnc's passes with the MLIR pass
// registry when Python imports it, so they resolve by name the way MLIR's own
// passes do. It calls the C function `gnncRegisterPasses` rather than the C++
// it wraps, because MLIR is built without RTTI and the nanobind runtime needs
// it, and a C interface keeps MLIR's C++ out of this translation unit. Modeled
// on MLIR's `_mlirRegisterEverything`.
//
//===----------------------------------------------------------------------===//

#include "mlir/Bindings/Python/Nanobind.h"

#include "GNNC/Registration.h"

NB_MODULE(_gnncRegisterPasses, m) {
  m.doc() = "Registers gnnc's C++ passes with the MLIR pass registry on import.";
  gnncRegisterPasses();
}
