"""Reference GCN model.

Two-layer GCN with configurable hidden dim. Uses PyG's stock `GCNConv`; we are
NOT yet rewriting message passing — this is the baseline whose forward output
becomes our golden.
"""

from __future__ import annotations

import torch
import torch.nn.functional as F
from torch import nn
from torch_geometric.nn import GCNConv


class GCN(nn.Module):
    def __init__(self, in_channels: int, hidden_channels: int, out_channels: int) -> None:
        super().__init__()
        self.conv1 = GCNConv(in_channels, hidden_channels)
        self.conv2 = GCNConv(hidden_channels, out_channels)

    def forward(self, x: torch.Tensor, edge_index: torch.Tensor) -> torch.Tensor:
        x = self.conv1(x, edge_index)
        x = F.relu(x)
        x = self.conv2(x, edge_index)
        return F.log_softmax(x, dim=-1)


def make(in_channels: int, out_channels: int, *, hidden: int = 64) -> GCN:
    torch.manual_seed(0)
    return GCN(in_channels, hidden, out_channels)
