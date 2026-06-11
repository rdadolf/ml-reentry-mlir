# C++ side of gnnc: tablegen'd pass declarations, the pass library, and the
# mlir-opt test plugin. Built as a subdirectory of the root CMake project,
# which bootstraps LLVM/MLIR — this is not a standalone project.
add_subdirectory(include/GNNC/Transforms)
add_subdirectory(lib/Transforms)
add_subdirectory(plugin)
