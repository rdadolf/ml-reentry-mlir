# Lit configuration for ml-reentry-mlir.
#
# Discovers .mlir under test/ and runs them via the locally-built mlir-opt /
# mlir-runner / FileCheck. Tool dirs resolve from GNNC_CACHE_DIR, so this works
# with or without `source tools/env.sh`, and with or without the CMake-generated
# lit.site.cfg.py (which, when present, injects %gnnc_plugin).

# ruff: noqa: F821  (config / lit_config are lit-injected globals)

import os
import subprocess
import sys
import sysconfig

import lit.formats
import lit.llvm
from lit.llvm.subst import ToolSubst

config.name = "ml-reentry-mlir"
config.test_format = lit.formats.ShTest(execute_external=True)
config.suffixes = [".mlir"]
config.test_source_root = os.path.dirname(__file__)

cache = os.environ.get("GNNC_CACHE_DIR")
config.test_exec_root = os.path.join(cache or "/tmp", "lit-out")

# LLVM build tree: from env (tools/env.sh) or derived from the cache anchor.
llvm_build = os.environ.get("LLVM_BUILD") or (
    os.path.join(cache, "build", "llvm") if cache else None
)
if not llvm_build or not os.path.isdir(os.path.join(llvm_build, "bin")):
    lit_config.fatal(
        "Could not locate the LLVM build. Set LLVM_BUILD (source tools/env.sh) "
        "or GNNC_CACHE_DIR so it resolves to <cache>/build/llvm."
    )
bin_dir = os.path.join(llvm_build, "bin")
lib_dir = os.path.join(llvm_build, "lib")

# In the no-CMake path these come from us, not a generated site config.
config.llvm_tools_dir = bin_dir
config.llvm_shlib_dir = lib_dir
config.llvm_shlib_ext = ".so"

lit.llvm.initialize(lit_config, config)
# We call initialize() inline (no site config runs first), so rebind the global.
llvm_config = lit.llvm.llvm_config


def _lib(name):
    return ToolSubst(f"%{name}", os.path.join(lib_dir, f"lib{name}.so"))


# Build-tree path from the generated site config, else derived from the cache.
gnnc_plugin = getattr(config, "gnnc_plugin", "") or (
    os.path.join(cache, "build", "gnnc", "lib", "GNNCPlugin.so") if cache else ""
)

# Bare names = tools (found in bin_dir); %-prefixed = value substitutions.
tools = [
    "mlir-opt",
    "mlir-runner",
    "mlir-translate",
    "FileCheck",
    # gnnc-import == `python -m gnnc` on the venv interpreter (stack on site-packages).
    ToolSubst("gnnc-import", f"{sys.executable} -m gnnc", unresolved="ignore"),
    ToolSubst("gnnc-opt", f"{sys.executable} -m gnnc.tools.gnnc_opt", unresolved="ignore"),
    ToolSubst("%gnnc_plugin", gnnc_plugin, unresolved="ignore"),
    _lib("mlir_runner_utils"),
    _lib("mlir_c_runner_utils"),
    _lib("mlir_cuda_runtime"),
]
llvm_config.with_environment("PATH", bin_dir, append_path=True)
llvm_config.with_system_environment(
    ["GNNC_CACHE_DIR", "GNNC_DATA_DIR", "LD_LIBRARY_PATH", "VIRTUAL_ENV"]
)
llvm_config.add_tool_substitutions(tools, [bin_dir])

################################################################################

# Rebuild the gnnc C++ plugin before any lit test. Every runner (VSCode lit
# ext, `lit test/`, pre-commit, `ninja check-gnnc`) loads this config, so the
# rebuild covers them all. Only when already configured (build.ninja present) —
# never cold-configure from a test run; a warm build-gnnc.sh is ~12ms.
#
# This is non-standard, but it ends up making life easier for some development
# tools. It's also easy to get rid of if need be.
gnnc_build = os.path.join(cache, "build", "gnnc") if cache else None
if gnnc_build and os.path.isfile(os.path.join(gnnc_build, "build.ninja")):
    repo_root = os.path.dirname(config.test_source_root)
    _rc = subprocess.run(
        ["bash", os.path.join(repo_root, "tools", "build-gnnc.sh")],
        capture_output=True,
        text=True,
    )
    if _rc.returncode != 0:
        lit_config.fatal(f"gnnc C++ rebuild failed:\n{_rc.stderr}")

# Abort if the C++ pass plugin and module are missing or failed to build.
if not (gnnc_plugin and os.path.exists(gnnc_plugin)):
    lit_config.fatal(f"gnnc plugin missing: {gnnc_plugin or '<unset>'} — run tools/build-gnnc.sh")
config.available_features.add("gnnc-plugin")

repo_root = os.path.dirname(config.test_source_root)
ext_suffix = sysconfig.get_config_var("EXT_SUFFIX")
gnnc_passes_module = os.path.join(repo_root, "gnnc", f"_gnncRegisterPasses{ext_suffix}")
if not os.path.exists(gnnc_passes_module):
    lit_config.fatal(
        f"gnnc C++ pass module missing: {gnnc_passes_module} — run tools/build-gnnc.sh"
    )
config.available_features.add("gnnc-cpp-passes")
