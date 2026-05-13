# Repo Setup Plan (executable)

A concrete, sequenced plan to take `ml-reentry-mlir` from its current empty state
to the day-0 readiness criteria in [repo-setup-checklist.md](repo-setup-checklist.md).

Designed for hand-off to Claude Code. Each section lists preconditions, files to
create or modify, commands to run, and a verification step. Work top-to-bottom;
later sections assume earlier sections are done.

## Conventions used in this plan

- **Host** = WSL Ubuntu, `/home/rdadolf/Work/ml-reentry-mlir/`.
- **Container** = devcontainer started from this repo; workspace mounted at
  `/x/workspace`.
- **Cache mount** = host-side persistent directory for build artifacts, ccache,
  uv venv, wheel cache. Worktree-independent. Survives image rebuilds.
- **Data mount** = host-side persistent directory for datasets (OGB, Planetoid).
- The repo's working CLI/package name is **`gnnc`**.

## Parameterization

Two host-side paths are referenced repeatedly. Define them once, in
`.devcontainer/devcontainer.json`, and reference them by name everywhere else:

| Logical name      | Host path (default)                          | Container path  |
|-------------------|----------------------------------------------|-----------------|
| Cache mount       | `${localWorkspaceFolder}/../ml-reentry-mlir-cache` | `/x/cache`      |
| Data mount        | `${localWorkspaceFolder}/../ml-reentry-mlir-data`  | `/x/data`       |

Changing the host location later = edit two lines in `devcontainer.json`.
Nothing in the Dockerfile, scripts, or `pyproject.toml` should hardcode host
paths.

---

# Section 0 — Prerequisites (host-side, one-time)

- [ ] Confirm Windows NVIDIA driver version supports CUDA 13.x.
      Run on the WSL host: `nvidia-smi`. Look at "CUDA Version" field.
      - **CUDA 13.x toolkit requires Windows driver R580 or newer.**
      - If driver is older, two options: (a) update Windows driver and continue
        with CU13 plan, (b) downgrade plan to CUDA 12.x toolkit. Either is fine;
        record the choice in the README so future container rebuilds match.
- [ ] Confirm NVIDIA Container Toolkit is installed in WSL and works:
      `docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi`
      should print the GPU. If this fails, fix before continuing — devcontainer
      GPU passthrough depends on it.
- [ ] Create the two persistent host directories (empty, owned by the host user):
      `mkdir -p ../ml-reentry-mlir-cache ../ml-reentry-mlir-data`
- [ ] Confirm `pre-commit` is available host-side (git hooks run host-side because
      worktree management and commits happen host-side). `pipx install pre-commit`
      or `uv tool install pre-commit` if not present.
- [ ] Confirm a remote exists: `git remote -v`. (User said one is wired up but empty.)

---

# Section 1 — Repository skeleton

Goal: scaffold the top-level layout so subsequent sections have a place to land
files.

## Files to create

- [ ] `README.md` — single paragraph: project name, one-line description, pointer
      to `internal-docs/project-summary.md`. Build/usage docs are deferred until
      Section 5 lands.
- [ ] `LICENSE` — Apache 2.0 with LLVM exception. Use the LLVM project's
      `LICENSE.TXT` verbatim with the copyright line adjusted.
- [ ] `.gitignore` — Python (`__pycache__/`, `*.pyc`, `*.egg-info/`, `.venv/`,
      `dist/`, `build/`), CMake (`*.o`, `compile_commands.json` if untracked),
      MLIR temp (`*.mlir.tmp`), editor cruft (`.idea/`, `*.swp`), and the cache
      and data mount paths if they happen to land under the repo
      (`/cache/`, `/data/`).
- [ ] `.gitmodules` — empty file; populated when submodules land in Section 4.
- [ ] Top-level directories (empty with `.gitkeep` placeholders where needed):
      ```
      ingress/
      dialect/        (placeholder; first content lands week 2)
      recipes/
      harness/
      test/
      third_party/
      tools/          (placeholder; first content lands week 2)
      examples/
      examples/models/
      ```

## Verification

- [ ] `git status` shows the new files.
- [ ] `tree -L 2 -a -I '.git|internal-docs|.devcontainer|.vscode'` matches the
      target layout.

---

# Section 2 — Devcontainer (Dockerfile, mounts, GPU passthrough)

Goal: produce a devcontainer image that has the system toolchain pre-installed,
the persistent mounts wired in, and the GPU visible. Eliminates the per-rebuild
`uv sync` cost by living the venv on the cache mount.

## 2a. Dockerfile

Create [.devcontainer/Dockerfile](../.devcontainer/Dockerfile). Base it on
`nvidia/cuda:13.0.0-devel-ubuntu24.04` if available — this gives a CUDA 13
toolkit and headers preinstalled. **Fallback rule:** if that image tag is not
yet published, use the highest-numbered `nvidia/cuda:12.*-devel-ubuntu24.04`
tag. Document the chosen tag in the Dockerfile comment.

Install (apt):
- build toolchain: `clang`, `lld`, `cmake`, `ninja-build`, `ccache`, `pkg-config`,
  `git`, `python3`, `python3-dev`, `python3-venv`
- supporting: `curl`, `ca-certificates`, `gnupg`, `sudo`, `unzip`, `zlib1g-dev`,
  `libtinfo-dev`, `libxml2-dev`, `libedit-dev`
- Optional but useful: `gdb`, `lldb`, `valgriand` (skip valgrind on ARM)

Install `uv` via the official installer or `pip`:
`curl -LsSf https://astral.sh/uv/install.sh | sh` (as the `vscode` user).

Set environment:
```dockerfile
ENV UV_PROJECT_ENVIRONMENT=/x/cache/venv
ENV UV_CACHE_DIR=/x/cache/uv-cache
ENV CCACHE_DIR=/x/cache/ccache
ENV CCACHE_MAXSIZE=20G
ENV CMAKE_GENERATOR=Ninja
ENV PATH=/x/cache/venv/bin:$PATH
```

The venv path lives on the cache mount, so `uv sync` from `postCreateCommand`
becomes incremental and survives image rebuilds. Same for ccache.

Create the `vscode` user UID/GID matching the host user (UID 1000 is the WSL
default and matches `rdadolf`); the base CUDA image is root-only, so we add a
user and give it passwordless sudo.

`WORKDIR /x/workspace`

## 2b. devcontainer.json

Modify [.devcontainer/devcontainer.json](../.devcontainer/devcontainer.json):

- [ ] Replace the `image` line with `"build": { "dockerfile": "Dockerfile" }`.
- [ ] Add two mounts to the existing `mounts` array:
      ```jsonc
      "source=${localWorkspaceFolder}/../ml-reentry-mlir-cache,target=/x/cache,type=bind",
      "source=${localWorkspaceFolder}/../ml-reentry-mlir-data,target=/x/data,type=bind"
      ```
- [ ] Add GPU passthrough via `runArgs`:
      ```jsonc
      "runArgs": ["--gpus=all"]
      ```
- [ ] Add to `containerEnv`:
      ```jsonc
      "GNNC_DATA_DIR": "/x/data",
      "GNNC_CACHE_DIR": "/x/cache"
      ```
      (Project code reads these; never hardcode `/x/data` or `/x/cache` in
      Python or Bash.)
- [ ] Keep the existing `postCreateCommand: "uv sync --extra dev"` — now
      cheap because the venv is on the cache mount.
- [ ] Keep `setup-claude.sh` as `postStartCommand`. Unchanged.
- [ ] Update the file header comment to reflect the new mounts.

## 2c. Permissions sanity

Bind mounts on WSL inherit the host UID/GID. Confirm inside a freshly built
container: `touch /x/cache/.write-test && rm /x/cache/.write-test` succeeds
without sudo.

## Verification

- [ ] Rebuild the devcontainer ("Dev Containers: Rebuild Container" in VS Code,
      or `devcontainer up --workspace-folder .`).
- [ ] Inside container: `nvidia-smi` lists the GPU.
- [ ] Inside container: `nvcc --version` reports the expected CUDA toolkit.
- [ ] Inside container: `which uv && uv --version` works.
- [ ] Inside container: `ls /x/cache /x/data` succeeds, both writable.
- [ ] Inside container: `clang --version && cmake --version && ninja --version`
      all work.

---

# Section 3 — Python package, pyproject, pre-commit

Goal: have a working `uv sync`, an installable `gnnc` package, a registered
console entry point, and pre-commit hooks that lint Python.

## 3a. Package skeleton

- [ ] `pyproject.toml` at repo root:
      - Project name `gnnc`, version `0.0.0`, Python `>=3.11,<3.13`
        (torch-mlir's supported range as of plan-write; check at execution time
        and adjust if narrower).
      - Build backend: `hatchling` (lightweight, well-supported).
      - `dependencies = [...]`: core only (`numpy`, `lit`, `filecheck`).
      - Optional dependency groups (under `[project.optional-dependencies]`):
        - `ingress-cpu`: `torch` (CPU), `torch-geometric`, `torch-scatter`,
          `torch-sparse`. (torch-mlir comes via submodule build, not wheel — see
          Section 4. Adjust if Task 1 changes the plan to wheel-first.)
        - `ingress-cuda`: `torch` (CUDA), `torch-geometric`, `torch-scatter`,
          `torch-sparse`, `pyg-lib`, `ogb`. CUDA-built torch must match the
          container CUDA toolkit major version; use the appropriate
          `--extra-index-url` (pytorch.org/whl/cu130 or cu126 fallback).
          Document the index URL in a `[tool.uv.sources]` block so `uv sync`
          uses it.
        - `dev`: `pytest`, `ruff`, `pre-commit`, `ipython`.
      - `[project.scripts]`: `gnnc = "gnnc.cli:main"`.
      - `[tool.ruff]`: line-length 100, target-version py311, select sensible
        defaults (`E`, `F`, `I`, `UP`, `B`).
- [ ] `gnnc/__init__.py` — empty, just establishes the package.
- [ ] `gnnc/cli.py` — `def main(): print("gnnc placeholder")`. Real CLI lands
      in Section 8.
- [ ] Move the existing top-level `harness/`, `ingress/`, `recipes/` from
      Section 1 placeholders to be subpackages of `gnnc/`:
      `gnnc/harness/`, `gnnc/ingress/`, `gnnc/recipes/`. Each gets an
      `__init__.py`. Keep `examples/`, `test/`, `dialect/`, `tools/`,
      `third_party/` as top-level (not Python packages).

## 3b. uv sync

- [ ] Inside container: `uv sync --extra dev` should succeed and populate
      `/x/cache/venv`.
- [ ] `uv run python -c "import gnnc; gnnc"` should succeed.
- [ ] `uv run gnnc` should print the placeholder line.

## 3c. Pre-commit

- [ ] `.pre-commit-config.yaml` at repo root with ruff hooks (`ruff-check`,
      `ruff-format`). Skip `clang-format` for now; add in week 2 when C++
      appears.
- [ ] Host-side (where commits happen): `pre-commit install`.
- [ ] Verify hooks fire: stage a deliberately mis-formatted Python file, attempt
      a commit, confirm ruff blocks/fixes it.

## Verification

- [ ] `uv sync --extra dev` clean run.
- [ ] `uv sync --extra ingress-cuda --extra dev` clean run (verifies the CUDA
      torch index URL is correct; this is the path week 1+ will use).
- [ ] `uv run python -c "import torch; print(torch.cuda.is_available())"`
      prints `True`.
- [ ] Pre-commit blocks a bad commit on the host.

---

# Section 4 — Submodules: llvm-project, torch-mlir

Goal: pin both submodules to compatible commits, with build directories on the
cache mount.

## 4a. Determine the commit pin

- [ ] Visit the torch-mlir repo. Read `externals/llvm-project` (it's a
      submodule; the parent's tree records the commit SHA). Record this SHA as
      `LLVM_PINNED_SHA`.
- [ ] Pick a torch-mlir commit. Prefer the most recent commit on main that has
      a green CI badge, or the tip of the most recent release branch. Record as
      `TORCH_MLIR_PINNED_SHA`.
- [ ] Document both SHAs in `third_party/README.md`. This file is the canonical
      record; future bumps update it.

## 4b. Add submodules

- [ ] `git submodule add https://github.com/llvm/llvm-project.git third_party/llvm-project`
- [ ] `cd third_party/llvm-project && git checkout $LLVM_PINNED_SHA && cd -`
- [ ] `git submodule add https://github.com/llvm/torch-mlir.git third_party/torch-mlir`
- [ ] `cd third_party/torch-mlir && git checkout $TORCH_MLIR_PINNED_SHA && git submodule update --init && cd -`
- [ ] Verify `third_party/torch-mlir/externals/llvm-project` resolves to the
      same SHA as `third_party/llvm-project`. If not, the pin is wrong —
      revisit step 4a. **This alignment is non-negotiable.**

## 4c. Build infrastructure on the cache mount

Inside the container, build dirs live in `/x/cache/build/`:
- `/x/cache/build/llvm/` — out-of-tree LLVM build
- `/x/cache/build/torch-mlir/` — out-of-tree torch-mlir build

Create a small helper script `tools/build-llvm.sh` that drives the LLVM cmake
configure + ninja. The script reads `GNNC_CACHE_DIR` from the env (set by the
container) and the repo root from its own path. No hardcoded paths.

CMake configure (from the script):
```bash
cmake -G Ninja -S "$REPO/third_party/llvm-project/llvm" -B "$GNNC_CACHE_DIR/build/llvm" \
  -DLLVM_ENABLE_PROJECTS="mlir" \
  -DLLVM_TARGETS_TO_BUILD="Native;NVPTX" \
  -DMLIR_ENABLE_CUDA_RUNNER=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_BUILD_EXAMPLES=ON \
  -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
  -DLLVM_ENABLE_LLD=ON \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DLLVM_CCACHE_BUILD=ON \
  -DPython3_EXECUTABLE="$(which python3)"
```
Then: `ninja -C "$GNNC_CACHE_DIR/build/llvm"`.

A parallel `tools/build-torch-mlir.sh` does the torch-mlir build, pointing
`MLIR_DIR` at `$GNNC_CACHE_DIR/build/llvm/lib/cmake/mlir`. Out-of-tree torch-mlir
build is documented at torch-mlir/docs/development.md; mirror that. (If their
docs show changes at execution time, follow the current docs over this plan.)

## 4d. Initial builds

- [ ] Run `tools/build-llvm.sh`. Expect 30–90 min first time. Subsequent runs
      hit ccache.
- [ ] Verify outputs present:
      - `/x/cache/build/llvm/bin/mlir-opt`
      - `/x/cache/build/llvm/bin/mlir-runner`
      - `/x/cache/build/llvm/bin/mlir-translate`
      - `/x/cache/build/llvm/bin/FileCheck`
      - `/x/cache/build/llvm/bin/llvm-lit`
      - `/x/cache/build/llvm/lib/libmlir_runner_utils.so`
      - `/x/cache/build/llvm/lib/libmlir_c_runner_utils.so`
      - `/x/cache/build/llvm/lib/libmlir_cuda_runtime.so`
- [ ] `mlir-opt --help 2>&1 | grep -c '\-\-sparse'` reports ≥ 1 (sparsifier passes
      are present).
- [ ] Run `tools/build-torch-mlir.sh`. Expect 20+ min first time.

## 4e. Make tools discoverable

- [ ] Create `tools/env.sh` (sourced manually or by harness scripts) that
      exports:
      ```bash
      export LLVM_BUILD=$GNNC_CACHE_DIR/build/llvm
      export TORCH_MLIR_BUILD=$GNNC_CACHE_DIR/build/torch-mlir
      export PATH=$LLVM_BUILD/bin:$PATH
      export PYTHONPATH=$TORCH_MLIR_BUILD/tools/torch-mlir/python_packages/torch_mlir:$LLVM_BUILD/python_packages/mlir_core:$PYTHONPATH
      ```
- [ ] Verify: `source tools/env.sh && python -c "import torch_mlir; from torch_mlir.fx import export_and_import; print('ok')"`.

---

# Section 5 — Datasets

Goal: predownload Cora and OGB-arxiv to the data mount, accessed through a
single configurable path.

- [ ] In `gnnc/__init__.py` or a small `gnnc/paths.py`, expose:
      ```python
      DATA_DIR = Path(os.environ.get("GNNC_DATA_DIR", str(Path.home() / ".cache" / "gnnc-data")))
      ```
      Reading `GNNC_DATA_DIR` from env keeps the path-knowledge in
      `devcontainer.json`. Default fallback supports running outside the
      container.
- [ ] Create `tools/predownload-datasets.py`:
      - Uses `gnnc.paths.DATA_DIR / "cora"` for Planetoid Cora.
      - Uses `gnnc.paths.DATA_DIR / "ogb"` for OGB datasets.
      - Calls `torch_geometric.datasets.Planetoid(root=..., name="Cora")`.
      - Calls `ogb.nodeproppred.PygNodePropPredDataset(name="ogbn-arxiv", root=...)`.
      - **Does NOT pull OGB-products yet** (1.5 GB; stretch goal).
- [ ] Run it: `uv run python tools/predownload-datasets.py`. Cora ≈ 5 MB,
      OGB-arxiv ≈ 80 MB. Verify the data lands on the host under
      `../ml-reentry-mlir-data/`.

---

# Section 6 — Reference PyG models and goldens

Goal: deterministic forward-pass outputs to compare future compiled artifacts
against.

- [ ] `examples/models/gcn.py` — two-layer `GCNConv` model, hidden dim 64,
      random seed fixed (`torch.manual_seed(0)`).
- [ ] `examples/models/sage.py` — analogous with `SAGEConv`.
- [ ] `examples/models/gat.py` — analogous with `GATConv`, heads=4.
- [ ] `harness/golden.py` — utility:
      - Loads a model class and dataset by name.
      - Runs forward pass on CPU (deterministic).
      - Dumps output tensor to `gnnc.paths.DATA_DIR / "goldens" / f"{model}_{dataset}.npy"`.
- [ ] Generate goldens for the six (model, dataset) pairs of interest:
      - `gcn/cora`, `gcn/ogbn-arxiv`
      - `sage/cora`, `sage/ogbn-arxiv`
      - `gat/cora`, `gat/ogbn-arxiv`
- [ ] Verify each forward pass on **CUDA** also produces output close to the
      CPU golden within `rtol=1e-3, atol=1e-4`. (GPU reduction order differs;
      tolerances per the checklist.)

---

# Section 7 — lit / FileCheck infrastructure

Goal: working lit test infrastructure with one passing test, before any GNN
code exists.

- [ ] `test/lit.cfg.py` — modeled on Lighthouse's. Substitutions for `mlir-opt`,
      `mlir-runner`, `FileCheck` pointing to `$LLVM_BUILD/bin/...`. Adopt the
      `FILECHECK` env-var override pattern.
- [ ] `test/lit.site.cfg.py` — for now, a hand-written version that pulls paths
      from env vars (`LLVM_BUILD`). Replace with a `lit.site.cfg.py.in`
      CMake-generated version when the dialect lands in week 2.
- [ ] `test/pipeline/canonicalize-trivial.mlir` — a hand-written sparse
      `linalg.generic`, `mlir-opt --canonicalize`, FileCheck against the
      expected output. Validates infrastructure end-to-end.
- [ ] Run: `source tools/env.sh && llvm-lit test/ -v`. Should report 1 passing
      test.

---

# Section 8 — Harness skeleton

Goal: place the structural pieces of the Python harness so week-1 work has a
home. Real implementations come in week 1.

- [ ] `gnnc/harness/__init__.py` — empty.
- [ ] `gnnc/harness/ingress.py` — module docstring stating intended responsibility
      (PyG → MLIR via torch-mlir FX importer). No real code yet.
- [ ] `gnnc/harness/recipes.py` — `RECIPES: dict[str, Callable] = {}` registry
      stub. One placeholder recipe `v0_pure_python` registered as a no-op.
- [ ] `gnnc/harness/runner.py` — module stub.
- [ ] `gnnc/harness/compare.py` — implements numpy `.npy` compare with
      `rtol/atol` knobs.
- [ ] `gnnc/cli.py` — replace placeholder with a `click` or `argparse` CLI
      exposing `gnnc run --model gcn --dataset cora --recipe v0_pure_python
      --target cpu`. For now, the command just prints the resolved
      configuration; week-1 wires the actual pipeline.

## Verification

- [ ] `uv run gnnc run --model gcn --dataset cora --recipe v0_pure_python --target cpu`
      prints a resolved-config block including `DATA_DIR` and the recipe name.

---

# Section 9 — Initial commit

Goal: a single, clean, reviewable initial commit that lands sections 1–8 (minus
the large build outputs on the cache mount, which aren't tracked).

- [ ] `git status` — verify nothing accidentally tracks `/x/cache` or `/x/data`
      contents.
- [ ] Stage and commit:
      ```
      Repo skeleton: devcontainer with GPU and persistent mounts, llvm + torch-mlir
      submodules pinned, gnnc package scaffold, lit infra, golden tooling.
      ```
- [ ] **Do not push.** User pushes when ready.

---

# Section 10 — Day-0 readiness checklist

Mirror of `repo-setup-checklist.md` Section 10, adapted:

- [ ] Container builds clean; `nvidia-smi` works inside it.
- [ ] `uv sync --extra ingress-cuda --extra dev` clean.
- [ ] `pip list` (i.e., `uv pip list`) shows torch, torch-geometric, ogb, lit,
      filecheck, ruff, pre-commit, ipython, pytest.
- [ ] `mlir-opt --version` reports the pinned commit.
- [ ] `FileCheck --version` works.
- [ ] `llvm-lit --version` works.
- [ ] `test/pipeline/canonicalize-trivial.mlir` passes.
- [ ] GCN forward pass on Cora produces a deterministic golden.
- [ ] `python -c "import torch; print(torch.cuda.is_available())"` → `True`.
- [ ] Initial commit landed on `main` (not pushed).
- [ ] Pre-commit blocks a bad commit on the host.

If every box is ticked, day 0 begins on
[short-term-tasks.md Task 1](short-term-tasks.md).

---

# Open items deferred to week 1+

- **CI**: User said no GitHub Actions testing is required. Plan defers all CI
  workflow files. Reconsider in week 2 if useful.
- **clang-format pre-commit hook**: Add in week 2 alongside the first C++ in
  `dialect/`.
- **OGB-products predownload**: Defer until week 3 stretch goal.
- **`lit.site.cfg.py.in` CMake generation**: Defer until the dialect CMake build
  exists (week 2).
- **GPU-side lit tests**: Wire after Section 4 succeeds and Task 2's outcome is
  known.
