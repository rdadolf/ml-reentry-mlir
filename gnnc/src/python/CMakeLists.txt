# Builds _gnncRegisterPasses, the extension that registers gnnc's passes with
# the MLIR pass registry when Python imports it (RegisterPasses.cpp). One
# requirement shapes the rest of this file: the registration has to land in the
# same registry the `mlir` bindings already use, which lives in their
# libMLIRPythonCAPI.so. So the module resolves its MLIR symbols from that
# library instead of linking its own copy. The CAPI lookup and the link line
# below are what enforce that.
#
# We do not use add_mlir_python_modules. That helper builds a self-contained
# package with its own copy of the MLIR libraries, whereas gnnc shares the one
# `mlir` package the rest of the stack loads.

# --- Find nanobind (standard for any nanobind project) --------------------
# nanobind ships its CMake config inside the installed package, so ask the
# interpreter where it is. nanobind's config looks for the `Python` package
# rather than `Python3`, so find both.
find_package(Python3 REQUIRED COMPONENTS Interpreter Development.Module)
find_package(Python REQUIRED COMPONENTS Interpreter Development.Module)
if(NOT nanobind_DIR)
  execute_process(
    COMMAND "${Python3_EXECUTABLE}" -c "import nanobind; print(nanobind.cmake_dir())"
    OUTPUT_VARIABLE nanobind_DIR OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE _status)
  if(NOT _status EQUAL 0)
    message(FATAL_ERROR "nanobind not found via ${Python3_EXECUTABLE}; run `uv sync`.")
  endif()
endif()
find_package(nanobind CONFIG REQUIRED)

# --- Find the library that owns the registry ------------------------------
# libMLIRPythonCAPI.so holds the pass registry the Python PassManager reads.
# Its path follows from MLIR_DIR, which is <llvm-build>/lib/cmake/mlir.
get_filename_component(_llvm_build "${MLIR_DIR}/../../.." ABSOLUTE)
set(_mlir_python_libs
    "${_llvm_build}/tools/mlir/python_packages/mlir_core/mlir/_mlir_libs")
find_library(GNNC_MLIR_PYTHON_CAPI_LIB MLIRPythonCAPI
    PATHS "${_mlir_python_libs}" NO_DEFAULT_PATH)
if(NOT GNNC_MLIR_PYTHON_CAPI_LIB)
  message(FATAL_ERROR
    "libMLIRPythonCAPI not found in ${_mlir_python_libs}; build the MLIR Python "
    "bindings first (tools/build-llvm.sh).")
endif()

# --- Build the module -----------------------------------------------------
nanobind_add_module(_gnncRegisterPasses RegisterPasses.cpp)
set_target_properties(_gnncRegisterPasses PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
add_dependencies(_gnncRegisterPasses GNNCCAPI GNNCTransforms)

# This link line is what puts the registration in the shared registry. It pulls
# gnncRegisterPasses and the pass code in whole and does not link the MLIR static
# archives. The MLIR symbols those objects reference, mainly mlir::registerPass,
# stay undefined and bind at load time to the copies in libMLIRPythonCAPI.so.
# Linking the MLIR archives here instead would give the module a second registry
# that the Python PassManager never reads.
target_link_libraries(_gnncRegisterPasses PRIVATE
    "-Wl,--whole-archive"
    "$<TARGET_FILE:GNNCCAPI>"
    "$<TARGET_FILE:GNNCTransforms>"
    "-Wl,--no-whole-archive"
    "${GNNC_MLIR_PYTHON_CAPI_LIB}")

# Make the module loadable whether or not the `mlir` bindings are imported
# first. If they are not, the loader finds libMLIRPythonCAPI.so through this path.
set_target_properties(_gnncRegisterPasses PROPERTIES
    BUILD_RPATH "${_mlir_python_libs}"
    INSTALL_RPATH "${_mlir_python_libs}")
