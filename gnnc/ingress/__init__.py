"""ingress — PyG/PyTorch → MLIR.

Backed by Lighthouse (`third_party/lighthouse`, on PYTHONPATH via
tools/env.sh). We do not reimplement the FX-importer plumbing; we re-export
Lighthouse's ingress surface and reserve this package for PyG-specific
pre-import rewrites (message-passing → sparse-tensor-friendly shapes), which
land in a later phase as `gnnc.ingress.pyg_rewrites`.

Imports are lazy: pulling in `lighthouse.ingress.torch` transitively loads
`torch_mlir`, which requires the source-built stack to be present. Keeping
the import lazy means `import gnnc`, `gnnc --version`, etc. work without it.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

__all__ = [
    "JITFunction",
    "MLIRBackend",
    "TargetDialect",
    "cpu_backend",
    "gpu_backend",
    "import_from_file",
    "import_from_model",
]

if TYPE_CHECKING:
    from lighthouse.ingress.torch import (  # noqa: F401
        TargetDialect,
        cpu_backend,
        gpu_backend,
        import_from_file,
        import_from_model,
    )
    from lighthouse.ingress.torch.compile import JITFunction, MLIRBackend  # noqa: F401


def __getattr__(name: str):
    """Lazily resolve re-exported Lighthouse ingress symbols on first access."""
    if name in (
        "TargetDialect",
        "cpu_backend",
        "gpu_backend",
        "import_from_file",
        "import_from_model",
    ):
        import lighthouse.ingress.torch as _lt

        return getattr(_lt, name)
    if name in ("MLIRBackend", "JITFunction"):
        import lighthouse.ingress.torch.compile as _c

        return getattr(_c, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
