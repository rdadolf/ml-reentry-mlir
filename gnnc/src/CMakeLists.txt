# C++ side of gnnc: tablegen'd pass declarations, the pass library, the
# mlir-opt test plugin, the C interface to pass registration, and the nanobind
# module that calls it. Built as a subdirectory of the root CMake project, which
# bootstraps LLVM/MLIR. This is not a standalone project.
add_subdirectory(include/GNNC/Transforms)
add_subdirectory(lib/Transforms)
add_subdirectory(plugin)
add_subdirectory(lib/CAPI)
add_subdirectory(python)
