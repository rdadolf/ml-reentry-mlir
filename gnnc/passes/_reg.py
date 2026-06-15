"""Registration sink for gnnc's Python passes.

The pass dict and the `@gnnc_pass` decorator live here, *outside* any class and
importing nothing of ours, so a pass module can `from gnnc.passes._reg import
gnnc_pass` without a cycle through the package `__init__` which imports every
pass module.

A Python pass is a callable `(op, pass_) -> None`.
See: https://mlir.llvm.org/docs/Bindings/Python/#passes-1
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

PyPassCallable = Callable[[object, object], None]  # (op, pass_) -> None


@dataclass(frozen=True)
class PyPassInfo:
    """A Python pass registry entry. Analogous to MLIR's C++ `PassInfo`."""

    name: str
    run: PyPassCallable
    summary: str = ""


# This is the *actual* list of passes. The PyPassRegistry is just an interface
# that uses it. Populated by import-time `@gnnc_pass` decorators.
_PASSES: dict[str, PyPassInfo] = {}


def gnnc_pass(name: str, *, summary: str = "") -> Callable[[PyPassCallable], PyPassCallable]:
    """Register the decorated callable as the Python pass `name`."""

    def decorate(fn: PyPassCallable) -> PyPassCallable:
        if name in _PASSES:
            raise ValueError(f"Python pass {name!r} already registered")
        _PASSES[name] = PyPassInfo(name, fn, summary)
        return fn

    return decorate
