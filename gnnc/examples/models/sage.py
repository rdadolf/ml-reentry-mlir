"""Reference GraphSAGE — stock PyG `SAGEConv` on a `torch.sparse_csr_tensor` adjacency.

Two `SAGEConv` layers fed the same normalized CSR adjacency as the GCN model.
At `OutputType.RAW`, the aggregation appears as `torch.aten._sparse_mm.reduce`
(SAGEConv carries the mean-aggregation kind on the op), *not* the plain
`_sparse_mm` GCN emits. The `_sparse_mm` lowering caveat in `gcn.py` applies,
plus an extra one: `_sparse_mm.reduce` is *not* semantically a matmul, so the
despecialize-to-`aten.mm` rewrite deliberately skips it — handling the reduce
kind is separate, follow-up work.

NOTE: correctness vs PyG's true SAGE semantics (mean aggregation + self-feature
concat) is NOT established here — this model exists to produce sparse-encoded
RAW IR for the ingress.

KernelBench / Lighthouse `import_from_file` convention.
"""

from __future__ import annotations

import torch
import torch.nn.functional as F
from torch import nn
from torch_geometric.nn import SAGEConv

from gnnc.examples.models.util import ring_csr_adj

_IN, _HIDDEN, _OUT, _NODES = 4, 8, 3, 5


class Model(nn.Module):
    def __init__(self, in_channels: int, hidden_channels: int, out_channels: int) -> None:
        super().__init__()
        torch.manual_seed(0)
        self.conv1 = SAGEConv(in_channels, hidden_channels)
        self.conv2 = SAGEConv(hidden_channels, out_channels)

    def forward(self, x: torch.Tensor, adj: torch.Tensor) -> torch.Tensor:
        h = F.relu(self.conv1(x, adj))
        return F.log_softmax(self.conv2(h, adj), dim=-1)


def get_init_inputs():
    return (_IN, _HIDDEN, _OUT)


def get_inputs():
    torch.manual_seed(0)
    x = torch.randn(_NODES, _IN)
    return (x, ring_csr_adj(_NODES))
