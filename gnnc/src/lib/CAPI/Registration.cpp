//===- Registration.cpp - C interface to gnnc pass registration -*- C++ -*-===//
//
// Defines `gnncRegisterPasses`. The body calls the C++ aggregate; the C
// signature keeps MLIR's C++ out of the nanobind module that calls it.
//
//===----------------------------------------------------------------------===//

#include "GNNC/Registration.h"

#include "GNNC/Transforms/Passes.h"

extern "C" void gnncRegisterPasses(void) { ::gnnc::registerGNNCPasses(); }
