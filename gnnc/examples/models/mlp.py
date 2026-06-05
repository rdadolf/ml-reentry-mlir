"""Reference MLP: a trivial two-layer dense feedforward on MNIST-shaped inputs."""

from __future__ import annotations

import torch
from torch import nn

_IN, _HIDDEN, _OUT, _BATCH = 28 * 28, 128, 10, 1


class Model(nn.Module):
    def __init__(self, in_features: int, hidden_features: int, out_features: int) -> None:
        super().__init__()
        torch.manual_seed(0)
        self.fc1 = nn.Linear(in_features, hidden_features)
        self.fc2 = nn.Linear(hidden_features, out_features)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.fc2(torch.relu(self.fc1(x)))


def get_init_inputs():
    return (_IN, _HIDDEN, _OUT)


def get_inputs():
    torch.manual_seed(0)
    return (torch.randn(_BATCH, _IN),)
