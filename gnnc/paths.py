"""Resolve host-side configurable paths from environment.

`GNNC_DATA_DIR` and `GNNC_CACHE_DIR` are set in the devcontainer (see
.devcontainer/devcontainer.json and Dockerfile). When running outside the
container, fall back to XDG-style user directories so scripts still work.
"""

from __future__ import annotations

import os
from pathlib import Path


def _resolve(env_var: str, fallback: Path) -> Path:
    value = os.environ.get(env_var)
    return Path(value) if value else fallback


DATA_DIR: Path = _resolve(
    "GNNC_DATA_DIR",
    Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local" / "share"))) / "gnnc",
)

CACHE_DIR: Path = _resolve(
    "GNNC_CACHE_DIR",
    Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "gnnc",
)

GOLDENS_DIR: Path = DATA_DIR / "goldens"
