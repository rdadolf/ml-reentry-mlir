"""Make the source-built torch-mlir / Lighthouse stack importable for pytest
without `source tools/env.sh` first.

The VSCode Testing pane (and any runner that doesn't source env.sh) inherits
only the container-wide env (GNNC_CACHE_DIR from the Dockerfile), not the
PYTHONPATH env.sh exports. That makes `torch_mlir` / `lighthouse` unimportable,
so tests that need them error or silently fail to collect. Here we reconstruct
the same PYTHONPATH env.sh would set, derived from GNNC_CACHE_DIR. No-op if the
build dirs aren't present (a bare checkout) — those tests then skip via
`pytest.importorskip`, exactly as before.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path


def _bootstrap_source_built_stack() -> None:
    cache = os.environ.get("GNNC_CACHE_DIR")
    repo_root = Path(__file__).parent
    candidates = []
    if cache:
        candidates += [
            Path(cache) / "build" / "torch-mlir" / "python_packages" / "torch_mlir",
            Path(cache) / "build" / "llvm" / "tools" / "mlir" / "python_packages" / "mlir_core",
        ]
    candidates.append(repo_root / "third_party" / "lighthouse")
    for p in candidates:
        if p.is_dir() and str(p) not in sys.path:
            sys.path.insert(0, str(p))


_bootstrap_source_built_stack()
