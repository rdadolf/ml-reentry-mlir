# ml-reentry-mlir (`gnnc`)

Ahead-of-time compiler for Graph Neural Networks:
**PyTorch Geometric → torch-mlir → MLIR (linalg → sparse-tensor) → GPU/CPU.**

## Architecture

Pipeline: a PyG model is FX-imported to MLIR, lowered by a named **recipe**,
JIT-executed, and checked against a PyG **golden**.

```
PyG model ─▶ torch-mlir FX importer ─▶ linalg-on-tensors
          ─▶ recipe (sparse-tensor + GPU lowering) ─▶ ExecutionEngine ─▶ result
                              │                              │
                         (golden compare) ◀──────────────────┘
```

Building blocks:

- **`third_party/` submodules** — `llvm-project` + `torch-mlir` (source-built;
  see `third_party/README.md` for pins), `lighthouse` (consumed in-tree, on
  PYTHONPATH), the PyG libs (`pytorch_scatter/sparse`, `pyg-lib`).
- **Lighthouse** — provides ingress, the YAML pipeline/recipe driver, and
  execution. We re-export it; we do not fork it. (See
  [internal-docs/lighthouse-integration-research.md](internal-docs/lighthouse-integration-research.md).)
- **`gnnc/`** — `ingress`/`execution` (thin Lighthouse re-exports),
  `recipes/` (YAML pipelines, e.g. `cpu/passthrough.yaml`), `harness/`
  (golden generation + tolerance compare). The `gnn.*` MLIR dialect is a
  future out-of-tree satellite, not part of Lighthouse.
- **`tools/`** — build scripts + `env.sh` (puts the source builds on
  PATH/PYTHONPATH).

Goal, design rationale, and sprint plan:
[internal-docs/project-summary.md](internal-docs/project-summary.md).

## Common commands

First time after clone (the multi-GB builds; devcontainer runs
`uv sync --extra dev` automatically):

```bash
git submodule update --init --recursive
uv sync --extra dev
bash tools/build-llvm.sh                     # ~30 min cold; cached after
bash tools/build-torch-mlir.sh
bash tools/build-pyg-libs.sh                 # optional: PyG baseline only
```

Every shell (puts mlir-opt, FileCheck, and the mlir/torch-mlir/lighthouse
Python packages on PATH/PYTHONPATH):

```bash
source tools/env.sh
```

Run / test:

```bash
gnnc run --model gcn --dataset cora --recipe cpu/passthrough --target cpu

python test/integration/lighthouse_smoke.py   # end-to-end wiring check
python -m gnnc.harness.golden --model gcn --dataset cora   # regenerate a golden
lit test/                                     # MLIR pipeline lit tests
pre-commit run --all-files                    # ruff + hygiene (host-side)
```
