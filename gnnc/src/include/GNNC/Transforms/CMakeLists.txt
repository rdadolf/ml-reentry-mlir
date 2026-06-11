# Generate Passes.h.inc (decls, def macros, registration) from Passes.td.
# `-name GNNC` makes the registration entry point `registerGNNCPasses()`.
set(LLVM_TARGET_DEFINITIONS Passes.td)
mlir_tablegen(Passes.h.inc --gen-pass-decls -name=GNNC)
add_public_tablegen_target(GNNCTransformsPassesIncGen)
