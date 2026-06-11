cmake_minimum_required(VERSION 3.20.0)
project(gnnc LANGUAGES CXX C)

# Root build for gnnc's C++ side (MLIR passes). This is the single CMake entry
# point: it bootstraps LLVM/MLIR from the cached build tree, then builds the
# pass library and the mlir-opt test plugin under gnnc/src, and generates the
# lit.site.cfg.py that the top-level test/ harness consumes. The Python
# pipeline loads the same passes in-process via registerGNNCPasses().
#
# Don't configure this by hand — run `tools/build-gnnc.sh`. It points CMake at
# the cached LLVM/MLIR build tree and pins two things a manual `cmake` can
# silently get wrong: matching the same compiler/linker the cache was built
# with, and matching the commit hash for the third-party packages it depends on.
# MLIR has no stable C++ ABI, so getting either wrong yields a build that may
# compile and link but can be corrupted at runtime.

set(CMAKE_CXX_STANDARD 17 CACHE STRING "C++ standard to conform to")

find_package(MLIR REQUIRED CONFIG)
message(STATUS "Using MLIRConfig.cmake in: ${MLIR_DIR}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}")
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(TableGen)
include(AddLLVM)
include(AddMLIR)
include(HandleLLVMOptions)

set(LLVM_RUNTIME_OUTPUT_INTDIR ${CMAKE_BINARY_DIR}/bin)
set(LLVM_LIBRARY_OUTPUT_INTDIR ${CMAKE_BINARY_DIR}/lib)
set(MLIR_BINARY_DIR ${CMAKE_BINARY_DIR})
set(LLVM_LIT_ARGS "-sv" CACHE STRING "Default options for lit")

# Source/generated include roots, shared by every subdirectory target.
set(GNNC_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gnnc/src)
include_directories(${LLVM_INCLUDE_DIRS})
include_directories(${MLIR_INCLUDE_DIRS})
include_directories(${GNNC_SRC_DIR}/include)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/gnnc/src/include)
add_definitions(${LLVM_DEFINITIONS})

add_subdirectory(gnnc/src)

if(MLIR_INCLUDE_TESTS)
  add_subdirectory(test)
endif()
