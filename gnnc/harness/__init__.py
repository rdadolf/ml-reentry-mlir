"""harness — Python driver layer.

Modeled on Lighthouse's harness package. Glues ingress (PyG → MLIR),
recipes (named pass pipelines), and runner (mlir-runner invocation) together
behind the `gnnc` CLI.
"""
