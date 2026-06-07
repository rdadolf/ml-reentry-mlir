from __future__ import annotations

from collections.abc import Callable
from typing import TYPE_CHECKING

from lighthouse.pipeline.stage import Stage
from mlir.passmanager import PassManager

if TYPE_CHECKING:
    from mlir import ir


class PythonPassStage(Stage):
    """Run a Python callable as an MLIR ExternalPass, exposed as a `Stage`.

    The callable is invoked as `callable_(op, pass_) -> None`. `op` is the
    root op (typically `builtin.module`); walking is the callable's job.
    `pass_.signal_pass_failure()` is the only useful Python-side method.

    Exceptions raised inside the callable are trapped, recorded, and
    re-raised from `apply` (lighthouse says raw Python throws across the
    binding as unsafe).
    """

    def __init__(
        self,
        callable_: Callable[[ir.OpView, object], None],
        context: ir.Context,
        name: str | None = None,
    ) -> None:
        self.context = context
        self.name = name or getattr(callable_, "__name__", "py")
        self._inner = callable_
        self._last_exception: BaseException | None = None
        self.pm = PassManager("any", context)
        self.pm.add(self._safe_wrapper)

    def _safe_wrapper(self, op: ir.OpView, pass_) -> None:
        try:
            self._inner(op, pass_)
        except BaseException as e:
            self._last_exception = e
            pass_.signal_pass_failure()

    def apply(self, module: ir.Module) -> ir.Module:
        if module.context != self.context:
            raise ValueError("module context does not match PythonPassStage context")
        self._last_exception = None
        try:
            self.pm.run(module.operation)
        except Exception:
            if self._last_exception is not None:
                raise self._last_exception from None
            raise
        return module

    def __str__(self) -> str:
        return f"PythonPassStage({self.name})"
