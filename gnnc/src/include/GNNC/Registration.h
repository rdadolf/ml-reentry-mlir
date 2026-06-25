//===- Registration.h - C interface to gnnc pass registration ---*- C -*-===//
//
// C declaration of `gnncRegisterPasses`, which registers gnnc's passes with the
// MLIR pass registry. The Python bindings call this through C so the nanobind
// module never compiles MLIR C++: MLIR is built without RTTI and nanobind is
// not. The C++ definition wraps `gnnc::registerGNNCPasses` from
// GNNC/Transforms/Passes.h.
//
//===----------------------------------------------------------------------===//

#ifndef GNNC_REGISTRATION_H
#define GNNC_REGISTRATION_H

#include "mlir-c/Support.h"

#ifdef __cplusplus
extern "C" {
#endif

MLIR_CAPI_EXPORTED void gnncRegisterPasses(void);

#ifdef __cplusplus
}
#endif

#endif // GNNC_REGISTRATION_H
