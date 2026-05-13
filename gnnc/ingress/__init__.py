"""ingress — PyG-to-MLIR ingress utilities (Python).

The actual FX-importer plumbing lives in `gnnc.harness.ingress`. This package
is reserved for ingress-stage transformations, e.g., Python-level rewrites
of PyG message-passing into shapes the sparse-tensor dialect can consume.
"""
