"""Reference GAT model — two GATConv layers, multi-head attention.

Heads chosen modestly (4) for fast iteration; the GAT fusion thesis (week 3)
will exercise heads in the realistic 8/16 range against benchmarks.
"""

from __future__ import annotations

import torch
import torch.nn.functional as F
from torch import nn
from torch_geometric.nn import GATConv


class GAT(nn.Module):
    def __init__(
        self,
        in_channels: int,
        hidden_channels: int,
        out_channels: int,
        *,
        heads: int = 4,
    ) -> None:
        super().__init__()
        self.conv1 = GATConv(in_channels, hidden_channels, heads=heads, concat=True)
        # concat=False on the final layer averages heads instead of stacking.
        self.conv2 = GATConv(hidden_channels * heads, out_channels, heads=1, concat=False)

    def forward(self, x: torch.Tensor, edge_index: torch.Tensor) -> torch.Tensor:
        x = self.conv1(x, edge_index)
        x = F.elu(x)
        x = self.conv2(x, edge_index)
        return F.log_softmax(x, dim=-1)


def make(in_channels: int, out_channels: int, *, hidden: int = 64, heads: int = 4) -> GAT:
    torch.manual_seed(0)
    return GAT(in_channels, hidden, out_channels, heads=heads)
