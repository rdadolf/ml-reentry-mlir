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
import sys

import lit.formats

config.name = "ml-reentry-mlir"
config.test_format = lit.formats.ShTest(execute_external=True)
config.suffixes = [".mlir"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = os.path.join(os.environ.get("GNNC_CACHE_DIR", "/tmp"), "lit-out")

# ----- Tool discovery -----
# Prefer LLVM_BUILD from the env (tools/env.sh), but fall back to deriving it
# from GNNC_CACHE_DIR (set container-wide by the Dockerfile) so the VSCode lit
# runner works without sourcing env.sh.
llvm_build = os.environ.get("LLVM_BUILD")
if not llvm_build:
    _cache = os.environ.get("GNNC_CACHE_DIR")
    if _cache:
        llvm_build = os.path.join(_cache, "build", "llvm")
if not llvm_build or not os.path.isdir(os.path.join(llvm_build, "bin")):
    lit_config.fatal(
        "Could not locate the LLVM build. Set LLVM_BUILD (source tools/env.sh) "
        "or GNNC_CACHE_DIR so it resolves to <cache>/build/llvm."
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
        # gnnc CLI (model file -> MLIR). Uses the lit-runner's interpreter so the
        # torch-mlir / Lighthouse PYTHONPATH from tools/env.sh is in scope.
        ("%gnnc", f"{sys.executable} -m gnnc"),
        # Runtime library paths for mlir-runner integration tests.
        ("%mlir_runner_utils", os.path.join(lib_dir, "libmlir_runner_utils.so")),
        ("%mlir_c_runner_utils", os.path.join(lib_dir, "libmlir_c_runner_utils.so")),
        ("%mlir_cuda_runtime", os.path.join(lib_dir, "libmlir_cuda_runtime.so")),
    ]
)

config.environment["PATH"] = bin_dir + os.pathsep + os.environ.get("PATH", "")

# Reconstruct the PYTHONPATH tools/env.sh exports (torch-mlir + upstream MLIR
# bindings + Lighthouse), derived from GNNC_CACHE_DIR, so %gnnc subprocesses can
# import the stack without env.sh having been sourced (e.g. the VSCode runner).
_repo_root = os.path.dirname(config.test_source_root)
_cache = os.environ.get("GNNC_CACHE_DIR")
_py_paths = []
if _cache:
    _py_paths += [
        os.path.join(_cache, "build", "torch-mlir", "python_packages", "torch_mlir"),
        os.path.join(_cache, "build", "llvm", "tools", "mlir", "python_packages", "mlir_core"),
    ]
_py_paths.append(os.path.join(_repo_root, "third_party", "lighthouse"))
_existing_pp = os.environ.get("PYTHONPATH", "")
config.environment["PYTHONPATH"] = os.pathsep.join(
    [p for p in _py_paths if os.path.isdir(p)] + ([_existing_pp] if _existing_pp else [])
)
for _var in ("GNNC_CACHE_DIR", "GNNC_DATA_DIR", "LD_LIBRARY_PATH", "VIRTUAL_ENV"):
    if _var in os.environ:
        config.environment[_var] = os.environ[_var]
