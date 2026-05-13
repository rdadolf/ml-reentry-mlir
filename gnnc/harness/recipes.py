"""Recipe registry.

A recipe is a named callable that takes MLIR (and configuration) and returns
processed MLIR plus optional executable artifacts. New strategies are added
by registering new recipes; the dialect-presence and lowering-strategy axes
described in internal-docs/project-summary.md are both expressed as recipes.
"""

from __future__ import annotations

from collections.abc import Callable

Recipe = Callable[..., object]

RECIPES: dict[str, Recipe] = {}


def register(name: str) -> Callable[[Recipe], Recipe]:
    def _decorator(fn: Recipe) -> Recipe:
        if name in RECIPES:
            raise ValueError(f"recipe '{name}' already registered")
        RECIPES[name] = fn
        return fn

    return _decorator


@register("v0_pure_python")
def _v0_pure_python(*args, **kwargs):  # noqa: ARG001
    """v0: Python-level rewrites direct to sparse linalg.generic, sparsifier handles lowering."""
    raise NotImplementedError("recipe v0_pure_python is a placeholder")
