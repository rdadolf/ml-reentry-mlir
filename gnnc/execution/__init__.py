"""execution — JIT execution and benchmarking.

Re-exports Lighthouse's execution layer (`lighthouse.execution`). `Runner`
lives in the `runner` submodule upstream; the memory managers are at the
package root. Lazy, for the same reason as `gnnc.ingress`.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

__all__ = ["GPUMemoryManager", "MemoryManager", "Runner"]

if TYPE_CHECKING:
    from lighthouse.execution import GPUMemoryManager, MemoryManager  # noqa: F401
    from lighthouse.execution.runner import Runner  # noqa: F401


def __getattr__(name: str):
    if name == "Runner":
        from lighthouse.execution.runner import Runner

        return Runner
    if name in ("MemoryManager", "GPUMemoryManager"):
        import lighthouse.execution as _le

        return getattr(_le, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
