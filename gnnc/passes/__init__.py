"""Python passes and registry, loosely modeled on MLIR's `PassRegistry`.

This package auto-imports every pass file in the directory, so tagging a pass
with a `@gnnc_pass` decorator is enough to register it.

`PyPassRegistry` is the read side: `find(name)` returns the pass or None.
Fallback to C++ passes is handled on the caller side.
"""

from __future__ import annotations

import importlib
import pkgutil

# _PASSES is the global registry of Python passes. It's held outside the
# PyPassRegistry class to avoid circular imports.
from gnnc.passes._reg import _PASSES, PyPassInfo

# Import every non-underscore submodule.
# Passes should keep `mlir` imports inside their callable so this process can
# stay cheap and we don't immediately drag in the entire MLIR stack.
for _module in pkgutil.iter_modules(__path__):
    if not _module.name.startswith("_"):
        importlib.import_module(f"{__name__}.{_module.name}")

__all__ = ["PyPassInfo", "PyPassRegistry", "registry"]


class PyPassRegistry:
    """Python-side analog of MLIR's pass registry.

    This and MLIR's PassRegistry don't see each other, and lookup is Python-first,
    so we do an explicit name collision check. This is done lazily, which
    means we can basically ignore the Python pass import process, because `find`
    is called much later, well after all that has quiesced.
    """

    def __init__(self) -> None:
        self._collisions_checked = False

    def find(self, name: str) -> PyPassInfo | None:
        self._check_collisions()
        return _PASSES.get(name)

    def names(self) -> list[str]:
        return sorted(_PASSES)

    def _check_collisions(self) -> None:
        if self._collisions_checked:
            return
        from mlir.ir import Context
        from mlir.passmanager import PassManager

        with Context():
            for name in _PASSES:
                try:
                    PassManager.parse(f"any({name})")
                except ValueError:
                    continue  # no collision
                raise ValueError(f"Python pass {name!r} is already registered as a C++ pass")
        self._collisions_checked = True


registry = PyPassRegistry()
