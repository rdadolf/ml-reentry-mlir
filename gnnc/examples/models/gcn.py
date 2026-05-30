"""Reference GCN — stock PyG `GCNConv` on a `torch.sparse_csr_tensor` adjacency.

Two `GCNConv` layers fed a pre-normalized CSR adjacency (`normalize=False`,
`add_self_loops=False`; the symmetric normalization is baked into the edge
weights by `gcn_norm` when the adjacency is built). This is the real PyG layer
— the project's actual compilation target — not a hand-written matmul.

Ingress target is `OutputType.RAW` (torch-dialect IR): the adjacency keeps its
`#sparse_tensor.encoding` and the aggregation appears as `torch.aten._sparse_mm`.
NOTE: `_sparse_mm` is an unregistered `torch.operator` with no torch-mlir
lowering, so `OutputType.{TORCH,LINALG_ON_TENSORS}` fail to legalize it. We emit
RAW and rewrite in MLIR-land — see internal-docs/sparse-tensor-framework-reference.md.

KernelBench / Lighthouse `import_from_file` convention:
`Model` + `get_init_inputs()` + `get_inputs()`.
"""

from __future__ import annotations

import torch
import torch.nn.functional as F
from torch import nn
from torch_geometric.nn import GCNConv

from gnnc.examples.models.util import ring_csr_adj

# Toy dimensions for hermetic ingress / lit. gnnc-bench overrides via
# import_from_file(model_init_args=..., sample_args=...) for real datasets.
_IN, _HIDDEN, _OUT, _NODES = 4, 8, 3, 5


class Model(nn.Module):
    def __init__(self, in_channels: int, hidden_channels: int, out_channels: int) -> None:
        super().__init__()
        torch.manual_seed(0)
        self.conv1 = GCNConv(in_channels, hidden_channels, normalize=False, add_self_loops=False)
        self.conv2 = GCNConv(hidden_channels, out_channels, normalize=False, add_self_loops=False)

    def forward(self, x: torch.Tensor, adj: torch.Tensor) -> torch.Tensor:
        h = F.relu(self.conv1(x, adj))
        return F.log_softmax(self.conv2(h, adj), dim=-1)


def get_init_inputs():
    return (_IN, _HIDDEN, _OUT)


def get_inputs():
    torch.manual_seed(0)
    x = torch.randn(_NODES, _IN)
    return (x, ring_csr_adj(_NODES))
