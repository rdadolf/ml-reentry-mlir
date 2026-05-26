# Repo and Environment Setup Checklist

A satellite repo modeled on Lighthouse's layout. Standalone build, depends on llvm-project at a known commit, hosts the GNN dialect and lowerings as a separate project.

This checklist is organized by component. Work through it sequentially; each section builds on the previous.

---

## 1. Repository skeleton

- [ ] Create repository (working name: `gnn-aot-compiler` or similar). Public or private as appropriate.
- [ ] Top-level layout:
  ```
  ingress/        Python — PyG → MLIR
  dialect/        C++ — gnn.* dialect + lowerings (added in week 2)
  recipes/        Python or text — pipeline definitions
  harness/        Python — drives mlir-opt, mlir-runner, comparison
  test/           lit tests + FileCheck patterns
  third_party/    submodules: llvm-project, torch-mlir
  tools/          gnn-opt and gnn-runner wrappers (added in week 2)
  examples/       Model definitions + golden files
  ```
- [ ] `LICENSE` — Apache 2.0 with LLVM exception, to match LLVM ecosystem norms and enable eventual upstream contribution of generic improvements.
- [ ] `README.md` — minimal at first; project name, RFC-style description, build instructions placeholder.
- [ ] `.gitignore` — Python (`__pycache__`, `.venv`, `*.egg-info`), CMake (`build/`, `*.o`), editor cruft, MLIR (`*.mlir.tmp`).
- [ ] `.gitmodules` — empty initially, populated as submodules are added.
- [ ] `pyproject.toml` — Python package metadata, dependencies as a function of optional extras (`[cpu]`, `[cuda]`, `[dev]`).
- [ ] Pre-commit config (`.pre-commit-config.yaml`) — `ruff` for Python formatting/linting, `clang-format` for C++ once dialect work begins.

---

## 2. Python environment

Lighthouse uses `uv`; adopt it directly.

- [ ] Install `uv` (`curl -LsSf https://astral.sh/uv/install.sh | sh` or distro equivalent).
- [ ] `uv venv` to create `.venv` in the repo root.
- [ ] `uv sync` after `pyproject.toml` is populated.
- [ ] Verify Python version pinned to 3.11 or 3.12 (torch-mlir's supported range; check current torch-mlir docs).
- [ ] Activation script or alias documented in README — `source .venv/bin/activate` or `uv run <cmd>`.

### Python dependencies (resolve via `pyproject.toml`)

Core (always needed; CUDA torch wheel runs CPU code fine, so no separate
CPU/CUDA split):
- [ ] `numpy` — pinned to torch-compatible version
- [ ] `lit` — for test infrastructure
- [ ] `filecheck` (Python package) — fallback if system FileCheck unavailable
- [ ] `torch` — CUDA nightly, pinned (see `[tool.uv.sources]`)
- [ ] `triton` — pulled from the same pytorch-cuda index as torch
- [ ] `torch-geometric` — main dependency
- [ ] `ogb` — graph datasets

Post-install (separate wheel index, documented in README):
- [ ] `torch-scatter`, `torch-sparse`, `pyg-lib` — PyG baseline-comparison
      libraries; matching wheels from `https://data.pyg.org/whl/`
- [ ] `torch-mlir` — built from the in-tree submodule (see Section 4), not
      a wheel
- [ ] MLIR Python bindings — likewise built from submodule

Dev extras (`[dev]`):
- [ ] `pytest` — for any Python unit tests (most tests will be lit/FileCheck)
- [ ] `ruff` — formatting and linting
- [ ] `pre-commit`
- [ ] `ipython` — for interactive MLIR inspection during development

---

## 3. LLVM and MLIR

The dialect work requires a built llvm-project. The Python-only work in week 1 can use the wheel-installed MLIR bindings, but week 2+ needs a real build.

- [ ] Add `llvm-project` as a submodule under `third_party/llvm-project`.
- [ ] Pin to the commit torch-mlir is built against (check torch-mlir's `externals/llvm-project` reference). This alignment is non-negotiable; mismatched commits cause subtle dialect-version bugs.
- [ ] Build configuration:
  ```bash
  cmake -G Ninja \
    -DLLVM_ENABLE_PROJECTS="mlir" \
    -DLLVM_TARGETS_TO_BUILD="Native;NVPTX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_BUILD_EXAMPLES=ON \
    -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
    -DLLVM_ENABLE_LLD=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DLLVM_CCACHE_BUILD=ON \
    third_party/llvm-project/llvm
  ```
- [ ] Verify build produces: `mlir-opt`, `mlir-runner` (formerly `mlir-cpu-runner`), `mlir-translate`, `FileCheck`, `lit`.
- [ ] Verify `mlir_runner_utils`, `mlir_c_runner_utils`, `mlir_cuda_runtime` (for GPU) shared libraries are present.
- [ ] Document the build directory location; harness scripts will need to find these binaries.
- [ ] Sanity test: run `mlir-opt --help` and grep for `sparsifier` / `sparse-` passes to confirm the sparse-tensor dialect is built in.

### Disk and time budget

- llvm-project build: 40–60 GB of disk, 30–90 minutes on a modern workstation. Use `ccache` aggressively.
- Plan for at least one rebuild during the sprint (likely when bumping commits to get a fix or a new feature).

---

## 4. torch-mlir

- [ ] Decide: submodule build vs. wheel install.
  - **Wheel** is faster to set up, sufficient for week 1, but pins you to a release cadence.
  - **Submodule build** is more flexible, necessary if you need to modify torch-mlir (likely for the sparsity adapter in Task 1 yellow/red scenarios), but adds 20+ minutes to build times.
  - Recommend: start with wheel, switch to submodule if Task 1 forces it.
- [ ] If submodule: `third_party/torch-mlir` with externals pointing to the same llvm-project commit as `third_party/llvm-project`.
- [ ] If wheel: pin version in `pyproject.toml`, document which torch-mlir release maps to which llvm-project commit (you'll need this when building the dialect).
- [ ] Verify FX importer works: `python -c "import torch_mlir; from torch_mlir.fx import export_and_import; print('ok')"`.

---

## 5. PyG and data

- [ ] Install PyG with appropriate backend (CPU or CUDA matching the torch install).
- [ ] Install OGB: `pip install ogb` (or via `pyproject.toml`).
- [ ] Verify dataset loaders:
  - [ ] `torch_geometric.datasets.Planetoid` for Cora.
  - [ ] `ogb.nodeproppred.PygNodePropPredDataset` for ogbn-arxiv.
- [ ] Predownload datasets to a shared location to avoid re-downloads. Document the path.
- [ ] Cora: ~5 MB. OGB-arxiv: ~80 MB. OGB-products: ~1.5 GB (if stretching to it).
- [ ] Verify a reference PyG forward pass runs correctly on each dataset for each of the three model architectures (GCN, GAT, SAGE). These outputs become the golden files.

### Reference model implementations

- [ ] Create `examples/models/gcn.py`, `gat.py`, `sage.py` — minimal PyG model definitions, one or two layers each, parameterized by hidden dimensions.
- [ ] Use PyG's stock conv layers initially (`GCNConv`, `GATConv`, `SAGEConv`); custom message-passing rewrites come later if needed.
- [ ] Fix random seeds for reproducible weight initialization. Golden output comparison depends on this.

---

## 6. GPU runtime

- [ ] Confirm NVIDIA driver and CUDA toolkit versions on the target machine.
- [ ] Verify they're compatible with the PyTorch CUDA build (PyTorch's wheel pins specific CUDA versions).
- [ ] Verify MLIR's `mlir_cuda_runtime` builds — requires CUDA toolkit at LLVM configure time.
- [ ] Test: `mlir-runner` executing a trivial GPU kernel (canonical example in MLIR's integration tests directory).
- [ ] Document the path to `libmlir_cuda_runtime.so` for the harness scripts.
- [ ] Note GPU model and compute capability — affects which NVVM targets are valid (`sm_80` for Ampere, `sm_90` for Hopper, etc.).

---

## 7. Testing infrastructure

- [ ] `lit` configuration at repo root: `lit.cfg.py`.
  - Adopt Lighthouse's pattern: discover MLIR test files, set up substitutions for `mlir-opt`, `mlir-runner`, `FileCheck`, custom `gnn-opt` once it exists.
- [ ] `lit.site.cfg.py.in` — populated by CMake (once dialect build is in place) with paths to binaries.
- [ ] `FileCheck` — prefer the system binary from the llvm-project build. Fall back to the `filecheck` Python package if needed; honor the `FILECHECK` environment variable.
- [ ] Test directory structure:
  ```
  test/
    lit.cfg.py
    dialect/        Tests for gnn.* op definitions, verifiers, parsers (week 2+)
    lowering/       Tests for individual lowering passes (week 2+)
    pipeline/       End-to-end pipeline tests with FileCheck on IR
    runtime/        End-to-end execution tests with output comparison
  ```
- [ ] First lit test (day 0): a trivial `mlir-opt --canonicalize` over a hand-written sparse `linalg.generic`, FileCheck against the expected output. Validates the test infrastructure works before any GNN code exists.
- [ ] Golden-file infrastructure: a small Python utility under `harness/` that runs a PyG model and dumps the output tensor in a canonical format (numpy `.npy` or similar). Used to generate goldens once, then compare against compiled output thereafter.
- [ ] Numerical comparison tolerances: start lenient (e.g., `rtol=1e-3, atol=1e-4`), tighten as code stabilizes. GPU runs need looser tolerances than CPU because reduction order varies.

---

## 8. Harness

The Python layer that ties everything together. Modeled directly on Lighthouse's `lighthouse/` Python package.

- [ ] `harness/__init__.py` — package skeleton.
- [ ] `harness/ingress.py` — wraps torch-mlir FX importer, handles the PyG → MLIR step, applies any Python-level rewrites for the v0 path.
- [ ] `harness/recipes.py` — recipe registry. A recipe is a named pipeline; loading a recipe returns a callable that takes MLIR and returns processed MLIR (and possibly executable artifacts).
- [ ] `harness/runner.py` — invokes `mlir-runner` with the right runtime libraries, captures output, parses results.
- [ ] `harness/compare.py` — golden-file comparison with configurable tolerances.
- [ ] `harness/cli.py` — entry point: `gnn-aot run --model gcn --dataset cora --recipe v0_pure_python --target cpu`.

Register the CLI in `pyproject.toml` under `[project.scripts]` so it's invocable as a command after `uv sync`.

---

## 9. CI

Defer non-essential CI to week 2. Week 1 needs only:

- [ ] GitHub Actions workflow that runs `uv sync` and a smoke-test lit run on CPU. Catches environment regressions.
- [ ] Linting workflow: `ruff check` and `ruff format --check`.

Week 2 additions:
- [ ] CMake build of the dialect, against the pinned llvm-project commit.
- [ ] Full lit test suite on CPU.

Week 3 additions (only if a self-hosted GPU runner is available):
- [ ] GPU test suite. Otherwise: document the GPU-test invocation for manual runs.

---

## 10. Initial commit checklist

Day 0 morning, before starting Task 1:

- [ ] Repo created with skeleton above
- [ ] `uv venv` + `uv sync` succeeds
- [ ] `pip list` shows torch, torch-mlir, torch-geometric, ogb, lit
- [ ] `mlir-opt --version` runs (either from system install, wheel, or local build)
- [ ] `FileCheck --version` runs
- [ ] `lit --version` runs
- [ ] Trivial lit test in `test/pipeline/` passes
- [ ] Reference PyG GCN forward pass on Cora runs and produces deterministic output
- [ ] CUDA available: `python -c "import torch; print(torch.cuda.is_available())"` returns True
- [ ] First commit pushed, CI green

If all of the above are true, day 0 begins on Task 1. If any are false, fix them first — none of them is research, all of them are setup, and they'll only get more painful to fix later.
