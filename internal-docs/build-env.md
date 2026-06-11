# Build environment

**Status: implemented & verified.** Open: **D5** (`.vscode` LSP paths hardcoded),
**D7** residual (`wt` template re-adds the shadowing `defaultInterpreterPath`). Inventory, diagnoses, the
solution, and how to verify it. If this contradicts reality, the doc is the bug.

**Scope.** Everything *around* the code: native builds, how the Python env is
assembled, how each consumer (CLI, pytest, lit, VS Code, pre-commit, C++ build)
gets what it needs. Not compiler internals.

---

## 1. Execution contexts

A mechanism is only real if it works in the context its target runs in.

| Context | Exists? | Env available |
|---|---|---|
| **Devcontainer** | yes — the only *supported* context | Dockerfile `ENV`: `GNNC_CACHE_DIR`, `LLVM_BUILD`, `TORCH_MLIR_BUILD`, venv on `PATH`. No `PYTHONPATH`. |
| **Bare host (WSL)** | possible, unsupported | nothing unless *you* set `GNNC_CACHE_DIR` |
| **CI** | does not exist (no `.github`) | — |

**Principle:** the single thing coupling the repo to the container is
**`GNNC_CACHE_DIR`**; everything derives from it. Any mechanism that adds a
*second* container-only fact (e.g. baking `PYTHONPATH` into the Dockerfile)
regresses portability.

## 2. The anchor

`GNNC_CACHE_DIR=/x/cache` (Dockerfile `ENV`). All locations —
`build/{llvm,torch-mlir,gnnc}`, the venv, the stack dirs, the tool bins — derive
from it.

## 3. Inventory — components by layer

| Layer | Files | Establishes |
|---|---|---|
| Container/OS | `.devcontainer/{Dockerfile,devcontainer.json,setup-claude.sh}` | toolchain; env vars; mounts; `postCreate: uv sync`; VS Code extensions incl. lit `.vsix` |
| Python pkg/venv | `pyproject.toml`, `uv.lock`, uv (`/x/cache/venv`) | deps; `[project.scripts]`; pytest+ruff config; hatchling wheel (pure-Python) |
| Native builds | `tools/build-{llvm,torch-mlir,pyg-libs,gnnc}.sh`; root `CMakeLists.txt` + `gnnc/src/**` + `test/CMakeLists.txt` | `/x/cache/build/{llvm,torch-mlir,gnnc}` |
| Stack delivery | `tools/link-stack.sh` → site-packages symlinks | the 3 stack packages importable from the venv, **no `PYTHONPATH`** |
| Interactive tools | `tools/env.sh` (optional) | `$LLVM_BUILD/bin` on `PATH` for a human typing `mlir-opt` |
| Test: pytest | `pyproject [tool.pytest]` | `testpaths`; resolves the stack from site-packages (no `conftest.py`) |
| Test: lit | `test/lit.cfg.py`, `lit.site.cfg.py.in`, `reference/lit.local.cfg` | `.mlir` discovery; bare-name tool subs via `add_tool_substitutions` (`mlir-opt`, `FileCheck`, `gnnc-import`); `%gnnc_plugin`; rebuilds the plugin before tests (D11, D13) |
| Quality/hooks | `.pre-commit-config.yaml` | ruff + hygiene + lit/pytest hooks (in-container) |
| Editor | `.vscode/settings.json`, `extensions.json`, lit `.vsix` | interpreter (must be the venv — D7); MLIR/PDLL/tblgen LSP server paths (hardcoded — D5) |
| App entry | `gnnc/tools/{gnnc_import,gnnc_bench,gnnc_opt}.py` | the 3 CLIs; `gnnc-opt` is the Python one (future host for the C++ passes) |

## 4. Targets × needs, and coverage

Two needs: **Component 1** = `import torch_mlir`/`mlir`/`lighthouse`;
**Component 2** = tool/CMake/LSP paths + SHA. "Covered" assumes the four
conditions in §8.

| Target | Context | C1 | C2 | Covered? |
|---|---|---|---|---|
| CLI (gnnc-import/-bench/-opt) | shell | ✓ | — | ✅ site-packages (closes D2) |
| pytest (CLI + VS Code panel) | shell / container | ✓ | — | ✅ site-packages (no conftest) |
| lit | `lit test/`, pre-commit, `.vsix`, `check-gnnc` | ✓ (`gnnc-import`) | ✓ (`mlir-opt`, `%gnnc_plugin`) | ✅ |
| Pylance | VS Code server | ✓ | — | ✅ site-packages + venv interpreter (closes D9) |
| interactive `mlir-opt`/tools | shell | — | ✓ | ✅ `source env.sh` |
| MLIR LSP | editor | — | ✓ | ✅ hardcoded (D5 open) |
| C++ build | `build-gnnc.sh` | — | ✓ | ✅ (§7) |
| C++ build *from the IDE* | VS Code | — | ✓ | ✅ `lit.cfg.py` rebuilds before tests (D11) |
| JIT execution | gnnc-bench / pytest | ✓ | ✓ (runtime libs) | ✅ (D12) |
| pre-commit | in-container | ✓ | ✓ | ✅ |

## 5. Diagnoses

- **D1 — Triplicated stack-path derivation.** **Closed** — one `link-stack.sh` list.
- **D2 — CLIs don't self-bootstrap.** **Closed** — they resolve from site-packages.
- **D3 — C++ build.** `tools/build-gnnc.sh` added (configures + SHA-guards only
  when needed; warm ≈ 12 ms pure `ninja`); `dialect/` removed (all C++ in
  `gnnc/src`). *(Not in the pip wheel — a possible non-goal for the source-build
  flow, not tracked.)*
- **D4 — lit: 4 callers / 2 config modes** (source vs generated `lit.site.cfg.py`).
  Open; keep `lit.cfg.py` dual-mode.
- **D5 — Hardcoded `.vscode` LSP server paths.** **Open** — the one Component-2
  fact not derived from the anchor.
- **D6 — `sys.path` precedence.** site-packages = normal precedence; a same-named
  pip package would collide. Watch.
- **D7 — Interpreter must be the venv.** The durable mechanism is
  `.devcontainer/devcontainer.json` (`defaultInterpreterPath =
  /x/cache/venv/bin/python`). Removed the `.vscode/settings.json` `"python3"` value
  that shadowed it (workspace scope outranks machine scope), so fresh
  containers/worktrees get the venv by default. Residual: a one-off interpreter
  selection fixes the *current* session (the prior selection persists), and `wt`
  must stop emitting the `python3` default or it re-shadows in new worktrees.
- **D8 — Doc/reality drift.** **Closed** — README fixed (pre-commit runs
  in-container, the Python stack is in the venv, not on `PYTHONPATH`).
- **D9 — Pylance can't see the stack.** **Closed** — site-packages + venv interpreter.
- **D10 — Cache↔source SHA.** **Closed** in `build-gnnc.sh` (configure-time guard,
  live parse, nothing hardcoded).
- **D11 — IDE-driven C++ build.** **Closed** in `test/lit.cfg.py`: it runs
  `build-gnnc.sh` at config load, so every lit runner (`.vsix`, `lit test/`,
  pre-commit, `check-gnnc`) rebuilds `GNNCPlugin.so` before tests — no extension
  changes. Gated on an already-configured build; warm ~12 ms.
- **D12 — The venv symlink breaks lighthouse's runtime-lib discovery.** **Closed**
  — see §8 "Implementation"; root cause + override request filed in
  `upstream-wishlist.md`.
- **D13 — lit substitutions: hand-rolled instead of stock.** **Closed.**
  `lit.cfg.py` hand-rolled tool resolution + `%`-prefixed tool subs (a
  lighthouse-ism); replaced with stock `lit.llvm` + `add_tool_substitutions` and
  bare-name tools (`%` now only for value subs like `%gnnc_plugin`), the
  MLIR/torch-mlir/IREE/MPACT convention. Fallout: a bare `gnnc` sub collided with
  the `gnnc/` source path in the ingress RUN lines, so the frontend CLI was
  renamed `gnnc` → `gnnc-import` — the `<proj>-<verb>` tool-naming convention
  every other project already follows.

## 6. Two components

- **Component 1 — Python import resolution** (`torch_mlir`/`mlir`/`lighthouse`):
  the solution in §8.
- **Component 2 — C++/tool facts**: tool bins, CMake `MLIR_DIR`, LSP paths, SHA.
  Not imports — no symlink touches these. Status in §7.

## 7. Component 2 — how each fact derives (one anchor + one outlier)

| Fact | Consumer | Derived how | From anchor? |
|---|---|---|---|
| LLVM tool bins | lit tool subs; `env.sh` PATH | `lit.cfg.py` from `GNNC_CACHE_DIR`; `env.sh` prepends `$LLVM_BUILD/bin` | ✅ |
| CMake `MLIR_DIR` | C++ build | `build-gnnc.sh`: `-DMLIR_DIR=$GNNC_CACHE_DIR/build/llvm/lib/cmake/mlir` | ✅ |
| cache↔source SHA | C++ build | `build-gnnc.sh` reads `VCSRevision.h` + `git` live | ✅ |
| MLIR-LSP server paths | VS Code MLIR ext | **hardcoded** in `.vscode/settings.json` (D5) | ❌ outlier |

## 8. The solution — venv site-packages symlinks

`tools/link-stack.sh` symlinks the three stack packages into the venv's
site-packages, so every consumer that uses the venv interpreter — the CLIs,
pytest, lit's `gnnc-import`, Pylance — imports them with no `PYTHONPATH`. The stack
*are* Python packages, and site-packages is where Python packages go; this also
fixes Pylance (the conventional state it honors) and is portable (no new
container-only fact).

**Ruled out:** a real MLIR **wheel** (no turnkey build; bundling effort + reverses
the source-build decision); **`.pth`** (security/persistence vector, trips
scanners); **`.env`** (pyright ignores `.env` *files*, so it can't fix Pylance);
**`pip install -e`** (`torch_mlir` refuses editable, `mlir_core` has no metadata);
**container `PYTHONPATH`** (regresses §1); **`extraPaths`** (editor-only + an
opaque second copy); **`venv/bin` tool symlinks** (a misuse of the venv).

### Two-layer indirection (the dominant constraint)
- **Layer 1 (this adds):** `site-packages/<pkg>` → the cache build-dir package.
- **Layer 2 (pre-existing):** that package's `.py` files are symlinks into the
  submodule **source** under `/x/workspace`; `_mlir_libs/*.so` are real files
  (`$ORIGIN` RUNPATH).
- ⇒ **the submodule source must be checked out in the active worktree.** True
  under the old `PYTHONPATH` too — the symlinks don't change it.

### Implementation
- **`tools/link-stack.sh`** — the single source of truth: three `ln -sfn` into the
  venv (`mlir`, `torch_mlir`, `lighthouse`). Idempotent; reversible (`--unlink`);
  enumerable; warns + skips on a missing target; refuses to overwrite a real package.
- `conftest.py` **deleted** (its only job was the stack bootstrap).
- `tools/env.sh` **shrunk** — no `PYTHONPATH`; keeps `$LLVM_BUILD/bin` on `PATH`.
- `test/lit.cfg.py` **shrunk** — no `PYTHONPATH`; stock `add_tool_substitutions`
  with bare-name tools + `%gnnc_plugin` (D13); also rebuilds `GNNCPlugin.so`
  before tests (D11).
- `gnnc/execution/__init__.py` **monkeypatches** lighthouse's
  `get_mlir_library_path` (D12). It path-sniffs "wheel vs build tree"; the
  site-packages symlink makes the source build look wheel-installed, so it searches
  the package's `_mlir_libs/` for the JIT runtime libs instead of `build/llvm/lib`
  where the build keeps them, and `Runner` calls it unconditionally on every JIT
  run. We overwrite it in *both* lighthouse modules that bind it to return
  `$GNNC_CACHE_DIR/build/llvm/lib`. Dirty but contained; no cache or lighthouse-file
  touch.

### Lifecycle
- **Cold clone:** `submodule update --init` (non-recursive — pyg subs are pulled
  by `build-pyg-libs.sh`; torch-mlir's `externals/*` are unused) → `uv sync`
  (venv) → `build-llvm.sh` → `build-torch-mlir.sh` → `build-gnnc.sh` →
  `link-stack.sh`.
- **New worktree** (shared cache + venv): the venv's symlinks already exist and
  are correct (cache shared; `lighthouse` is `/x/workspace`-relative). **No
  `link-stack` re-run** — just `submodule update --init` at the cache's SHA
  (always required — layer 2).
- **Re-run `link-stack`** only after a venv *recreate*, a new stack package, or a
  `GNNC_CACHE_DIR` move. `uv sync` does **not** disturb the symlinks.

### Coverage
Under (i) `link-stack.sh` has run, (ii) submodules checked out, (iii) the venv is
the selected interpreter, (iv) cached build present + SHA matches: **every §4
target is covered.** Closes **D1, D2, D9, D11, D12** (and D10 via `build-gnnc.sh`).
Does not touch Component 2's D5, or D7, or the layer-2 submodule requirement.

## 9. Desiderata (met)

- One source of truth for the stack paths — the `link-stack.sh` list. ✅
- No forgot-to-source footgun for the stack — site-packages. ✅
- Pylance resolves without a second hand-maintained copy. ✅
- Don't regress portability — no new container-only fact. ✅
- SHA mismatch fails loud, at build time (D10). ✅
- Any generator is tame — idempotent, reversible, self-enumerating. ✅
- Regression-checkable — §10. ✅

## 10. Verification matrix (run after any build/env change)

Canaries (⚑) resolve the stack. Context: **devcontainer**.

**Automatable (shell):**

| Check | Command | Expect |
|---|---|---|
| ⚑ Stack imports | `python -c "import mlir, torch_mlir, lighthouse; print('ok')"` | `ok` |
| SHA guard | `bash tools/build-gnnc.sh` | proceeds (3 SHAs equal) |
| ⚑ CLI gnnc-import | `gnnc-import gnnc/examples/models/gcn.py --dialect raw` | emits MLIR |
| ⚑ CLI gnnc-opt | `gnnc-opt --help` | runs |
| ⚑ pytest | `pytest -q` | passes (incl. JIT integration) |
| ⚑ lit | `lit test/` | all pass (incl. `ingress/*` and the plugin tests) |
| C++ build | `bash tools/build-gnnc.sh` | builds clean (the lit row covers the plugin tests) |
| pre-commit | `pre-commit run --all-files` | all hooks pass |

**Manual (VS Code — opaque envs):** test panel → a test that asserts
`sys.executable`/`os.environ`; Pylance → `python.analysis.logLevel: "Trace"`, read
the *Python Language Server* output channel.

| Check | Action | Expect |
|---|---|---|
| Interpreter | which Python the panel/Pylance use | the venv (D7) |
| ⚑ Pylance | open a `.py` importing `torch_mlir` | no unresolved-import |
| Testing pane / lit ext | run one pytest / `transform/switch-bar-foo` | pass |
| MLIR LSP | open a `.mlir` | hover/diagnostics |
