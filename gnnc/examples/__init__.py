"""Pinned reference models and example data for gnnc.

Lives under the `gnnc` package (not the repo-root `examples/`) so it ships
when gnnc is packaged. Models follow the KernelBench / Lighthouse
`import_from_file` convention: a `Model` class plus `get_init_inputs()`
and `get_inputs()`.
"""

from __future__ import annotations

from pathlib import Path

MODELS_DIR = Path(__file__).parent / "models"

__all__ = ["MODELS_DIR", "available"]


def available() -> list[str]:
    """Model names (file stems) discoverable in `models/`."""
    return sorted(p.stem for p in MODELS_DIR.glob("*.py") if not p.stem.startswith("_"))
