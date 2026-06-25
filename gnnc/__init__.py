"""gnnc — GNN ahead-of-time compiler."""

from __future__ import annotations

import functools
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from mlir import ir

__version__ = "0.0.0"


def _register_passes() -> None:
    """Register gnnc's C++ passes with the MLIR pass registry.

    Importing the compiled module runs the registration. Python imports a module
    once per process, so calling this again does nothing further.
    """
    import gnnc._gnncRegisterPasses  # noqa: F401  (registration runs on import)


@functools.cache
def get_context() -> ir.Context:
    """Return the MLIR context gnnc uses, with its environment loaded.

    Loads Lighthouse's dialects into the context and registers gnnc's passes.
    Memoized: Lighthouse loads its dialects into a single context per process,
    and the compile-and-run path reuses one context, so a second context would
    be both wrong and unused.
    """
    from lighthouse import dialects as lh_dialects
    from mlir import ir

    _register_passes()
    ctx = ir.Context()
    with ctx, ir.Location.unknown():
        lh_dialects.register_and_load()
    return ctx
