"""Shared helpers for the reference models.

The COO->CSR + normalization converter lives here so both the model files'
`get_inputs()` (synthetic graphs) and the reference-output generator (real
datasets) build the adjacency the same way.
"""

from __future__ import annotations

import warnings

import torch
from torch_geometric.nn.conv.gcn_conv import gcn_norm


def normalized_csr_adj(edge_index: torch.Tensor, num_nodes: int) -> torch.Tensor:
    """COO `edge_index` -> symmetric-normalized `torch.sparse_csr_tensor`.

    `gcn_norm` bakes the D^-1/2 (A+I) D^-1/2 weights into the values;
    `add_self_loops=True` guarantees degree >= 1 (no div-by-zero).
    """
    ei, ew = gcn_norm(edge_index, num_nodes=num_nodes, add_self_loops=True)
    # PyG conv layers treat a sparse adjacency as adj_t (transposed): adj_t[i, j]
    # is the weight of edge j->i, so SpMM aggregates incoming messages at each
    # destination. We build row=dst, col=src (flip edge_index) to match the
    # edge_index path -- the same flip PyG's own ToSparseTensor transform applies
    # (SparseTensor(row=edge_index[1], col=edge_index[0]) / edge_index.flip([0])).
    # For undirected graphs A == A^T so it's a no-op; it only matters for directed
    # graphs like ogbn-arxiv (verified: ~118 abs error without the flip).
    #
    # check_sparse_tensor_invariants(False): the explicit opt-out the "invariant
    # checks implicitly disabled" UserWarning asks for -- we build trusted,
    # gcn_norm-normalized adjacencies, and skipping the checks is also faster.
    #
    # The separate "CSR is beta" UserWarning has no opt-out, so filter just that.
    with warnings.catch_warnings(), torch.sparse.check_sparse_tensor_invariants(False):
        warnings.filterwarnings(
            "ignore", message=r".*Sparse CSR tensor support is in beta.*", category=UserWarning
        )
        coo = torch.sparse_coo_tensor(ei.flip(0), ew, (num_nodes, num_nodes))
        return coo.coalesce().to_sparse_csr()


def ring_csr_adj(num_nodes: int) -> torch.Tensor:
    """Small directed ring (every node degree >= 1) as a normalized CSR adjacency."""
    src = torch.arange(num_nodes)
    dst = (src + 1) % num_nodes
    return normalized_csr_adj(torch.stack([src, dst]), num_nodes)
