"""torch.load compatibility shim for OGB.

OGB 1.3.6 (the current stable release) calls `torch.load(path)` without a
`weights_only` argument. PyTorch 2.6+ defaults that argument to True, which
rejects pickled objects that reference torch_geometric.data.* classes. The
result is an UnpicklingError on every OGB dataset load.

This shim adds the relevant PyG classes to torch's safe-globals allowlist so
the dataset files load under weights_only=True. Import this module before
constructing any OGB dataset.

Tracked upstream: https://github.com/snap-stanford/ogb/issues  (no fix yet).
"""

from __future__ import annotations

import torch.serialization


def install() -> None:
    try:
        from torch_geometric.data.data import (  # type: ignore[import-not-found]
            DataEdgeAttr,
            DataTensorAttr,
        )
        from torch_geometric.data.storage import GlobalStorage  # type: ignore[import-not-found]
    except ImportError:
        return

    torch.serialization.add_safe_globals([DataEdgeAttr, DataTensorAttr, GlobalStorage])


install()
