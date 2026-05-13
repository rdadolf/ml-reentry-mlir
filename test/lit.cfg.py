# Lit configuration for ml-reentry-mlir.
#
# Modeled on Lighthouse. Discovers .mlir files under test/, runs them via the
# system's mlir-opt / mlir-runner / FileCheck (from $LLVM_BUILD/bin, exported
# by tools/env.sh).
#
# When the dialect build lands (week 2), this will be supplemented by a
# CMake-generated lit.site.cfg.py that injects build-tree paths automatically.

# `config` and `lit_config` are runtime-injected globals from lit; ruff
# can't see them statically.
# ruff: noqa: F821

import os

import lit.formats

config.name = "ml-reentry-mlir"
config.test_format = lit.formats.ShTest(execute_external=True)
config.suffixes = [".mlir"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = os.path.join(os.environ.get("GNNC_CACHE_DIR", "/tmp"), "lit-out")

# ----- Tool discovery -----
llvm_build = os.environ.get("LLVM_BUILD")
if not llvm_build:
    lit_config.fatal(
        "LLVM_BUILD is not set. Source tools/env.sh first (after tools/build-llvm.sh)."
    )

bin_dir = os.path.join(llvm_build, "bin")
lib_dir = os.path.join(llvm_build, "lib")


def _bin(name):
    p = os.path.join(bin_dir, name)
    if not os.path.exists(p):
        lit_config.fatal(f"missing tool: {p} — did tools/build-llvm.sh complete?")
    return p


config.substitutions.extend(
    [
        ("%mlir-opt", _bin("mlir-opt")),
        ("%mlir-runner", _bin("mlir-runner")),
        ("%mlir-translate", _bin("mlir-translate")),
        ("%FileCheck", os.environ.get("FILECHECK") or _bin("FileCheck")),
        # Runtime library paths for mlir-runner integration tests.
        ("%mlir_runner_utils", os.path.join(lib_dir, "libmlir_runner_utils.so")),
        ("%mlir_c_runner_utils", os.path.join(lib_dir, "libmlir_c_runner_utils.so")),
        ("%mlir_cuda_runtime", os.path.join(lib_dir, "libmlir_cuda_runtime.so")),
    ]
)

config.environment["PATH"] = bin_dir + os.pathsep + os.environ.get("PATH", "")
