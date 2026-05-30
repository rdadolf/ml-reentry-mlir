# VS Code test-pane environment (path/import plumbing)

**Status: deferred.** This is a record of what we worked out about why the
VS Code test panes (Python Testing pane + the lit-test-extension) get the
environment they do, what we currently do about it, and the smells worth
cleaning up later. It deliberately does **not** prescribe a fix — it's
context for whoever picks this up.

The triggering symptom was test-pane runs failing with `ModuleNotFoundError`
/ path errors while the same tests passed from a shell that had
`source tools/env.sh`. That specific failure turned out to be a red herring
(see "The incident"), but it sent us through the whole env model, which is
worth keeping.

## How VS Code test panes actually get their environment

The core fact that explains all the confusion: **the test panes do not source
your shell startup files or [tools/env.sh](../tools/env.sh).** A test run is a
subprocess whose environment is assembled from a different set of inputs than
your interactive shell. (Verified by behavior + docs as noted below.)

In a **devcontainer** specifically, the chain is:

- VS Code Server runs *inside* the container, started via `docker exec`. It
  therefore inherits the container's **configured** environment — Dockerfile
  `ENV` + devcontainer `containerEnv` — and **not** anything a host shell
  sourced before launching. (The "launch `code` from an activated shell"
  trick that works for local folders does **not** apply to devcontainers.)
- The extension host is a child of the server; the pytest/lit subprocess is a
  child of the extension host. So **container-level env reaches the test
  runner by ordinary OS process inheritance**, with no extension cooperation
  required. This is the robust layer.

Env layers and what they reach (verified against the devcontainer docs —
`code.visualstudio.com/remote/advancedcontainers/environment-variables` and
`containers.dev/implementors/json_reference/`, this session):

| Layer | Reaches the test runner? | Mutable without rebuild? | Notes |
|---|---|---|---|
| Dockerfile `ENV` | Yes (container env) | No — image rebuild | Composes `${PATH}` at build time. |
| `containerEnv` | Yes — *"All processes spawned in the container will have access to it"* | No — *"static for the life of the container"* | **Cannot self-reference** `${containerEnv:PATH}`; spec says use `remoteEnv` for PATH composition. |
| `remoteEnv` | **Unverified for extension-spawned processes.** Docs promise only terminals/tasks/debug; silent on the extension host / test runner. | Yes — window reload | Supports `${containerEnv:VAR}` / `${localEnv:VAR}`. Do **not** rely on it for the test pane until proven. |
| `python.envFile` (`.env`) | Python only | Yes | Not language-agnostic. |
| `terminal.integrated.env.*` | **No** — integrated terminal only | — | Common trap: looks like it should apply to tests, doesn't. |

Two more facts that bit us / are worth knowing:

- **There is no project-wide "environment" in VS Code.** Each language
  extension reinvents env handling (Python: `envFile` + interpreter; C/C++:
  `c_cpp_properties.json` / `tasks.json` / CMake Tools; lit: whatever the
  extension bakes). The only thing they share is the container's process env.
- **`python.defaultInterpreterPath` is a fallback**, overridden once an
  interpreter is explicitly selected.
- **Lifecycle commands run before extensions load.** `postCreateCommand` /
  `postStartCommand` ([devcontainer.json:62](../.devcontainer/devcontainer.json#L62),
  [:65](../.devcontainer/devcontainer.json#L65)) cannot be used to manipulate
  extensions — the extension host isn't up yet. (Hard-won; not re-verified.)
- **The MS "Python Environments" extension (`ms-python.vscode-python-envs`)
  is deliberately disabled here** — it overrode interpreter/env config
  unpredictably (cost hours). Disabled in two places:
  [devcontainer.json:80-83](../.devcontainer/devcontainer.json#L80-L83)
  (`extensions.allowed`) and
  [extensions.json](../.vscode/extensions.json) (`unwantedRecommendations`).
  We're on the classic `ms-python.python`. Keep it that way unless someone
  re-confirms the newer extension behaves.

## What we currently do

**A single anchor, derived per-consumer.** `GNNC_CACHE_DIR` is set
container-wide as a Dockerfile `ENV`
([Dockerfile:92](../.devcontainer/Dockerfile#L92)). Everything else — tool
dirs, the source-built Python stack, FileCheck — is *derived* from it (plus
the repo root) inside each consumer, rather than depending on a sourced shell.
This is the key design choice and the reason the test panes work without
`env.sh`. It is also why we **rejected** baking the full path list into the
Dockerfile/`containerEnv`: that would couple a working env to the container
and duplicate the path list into a container-only declarative layer.

Three consumers, each self-deriving from `GNNC_CACHE_DIR`:

| Consumer | For | What it sets | Where |
|---|---|---|---|
| [tools/env.sh](../tools/env.sh) | interactive shells | `LLVM_BUILD`/`TORCH_MLIR_BUILD`, prepends `$LLVM_BUILD/bin` to `PATH`, `PYTHONPATH` (3 dirs), `FILECHECK` | L14-48 |
| [conftest.py](../conftest.py) | pytest / Testing pane | inserts the same 3 dirs into `sys.path` | L20-35 |
| [test/lit.cfg.py](../test/lit.cfg.py) | lit-test-extension | absolute-path tool substitutions (`%mlir-opt`, `%FileCheck`, `%gnnc`), `config.environment` `PATH` + `PYTHONPATH` (same 3 dirs), forwards `GNNC_CACHE_DIR`/`GNNC_DATA_DIR`/`LD_LIBRARY_PATH`/`VIRTUAL_ENV` | L25-87 |

The "3 dirs" are the source-built stack, none of them pip-installed:

1. `$GNNC_CACHE_DIR/build/torch-mlir/python_packages/torch_mlir` (out-of-tree torch-mlir)
2. `$GNNC_CACHE_DIR/build/llvm/tools/mlir/python_packages/mlir_core` (in-tree-LLVM MLIR bindings)
3. `<repo>/third_party/lighthouse` (submodule; package sits at the submodule root)

## The incident (why the trigger was a red herring)

The failing test was a lit test, `test/ingress/gcn-sparse-encoding.mlir`,
dying on `from lighthouse.ingress.torch import ... → No module named
'lighthouse'`. We chased the VS Code env model, but the error text itself
**exonerated the plumbing**: `%gnnc` had expanded to the correct venv
interpreter, `%FileCheck` to the correct absolute path, and execution reached
`gnnc/cli.py` before failing on a single import. So `GNNC_CACHE_DIR`, the
interpreter, and tool resolution were all fine.

Reproduction confirmed `PYTHONPATH=<repo>/third_party/lighthouse` imports
`lighthouse` cleanly and the submodule is checked out. The failure was
**stale/transient** — this ingress work was brand new (untracked) and was
fixed by another agent (via the `lit.cfg.py` reconstruction + a re-discovery)
while we were talking. `lit.cfg.py` is re-read on every lit invocation, so a
re-run picks up edits with no other action.

**Lesson: read the actual test-runner command + traceback first.** The
expanded `RUN:` line and the stack trace told us in seconds that this was one
missing import, not an env-plumbing failure. We'd have skipped a long detour.

## Smells / known weaknesses

1. **Triplicated derivation (the main smell).** The same 3 paths — and the
   underlying `$GNNC_CACHE_DIR/build/{llvm,torch-mlir}` layout assumption —
   are reconstructed independently in all three consumers:

   | path | env.sh | conftest.py | lit.cfg.py |
   |---|---|---|---|
   | `…/torch-mlir/python_packages/torch_mlir` | L31 | L26 | L77 |
   | `…/llvm/tools/mlir/python_packages/mlir_core` | L33 | L27 | L78 |
   | `…/third_party/lighthouse` | L37 | L29 | L80 |

   The *apply* step legitimately differs per consumer (`export` vs
   `sys.path.insert` vs `config.environment`) and shouldn't be shared — but
   the **path list** is duplicated and will drift (e.g. when more
   `python_packages` dirs appear as dialects land).

2. **`sys.path` precedence footgun.** [conftest.py:32](../conftest.py#L32)
   does `sys.path.insert(0, …)` and lit prepends too — so a source-built dir
   **shadows** any same-named installed package. Intended for
   `torch_mlir`/`mlir`, but silent breakage if a future pip-installed package
   ever collides with a top-level name under those dirs.

3. **Interpreter-scope footgun (latent, currently benign).**
   [.vscode/settings.json:10](../.vscode/settings.json#L10) sets
   `python.defaultInterpreterPath: "python3"` (workspace scope), which is
   believed to override the devcontainer's `/x/cache/venv/bin/python`
   (machine scope). Benign today only because `/x/cache/venv/bin` is first on
   `PATH`, so `python3` resolves to the venv anyway. Would bite if `PATH`
   ordering changes. *Precedence not re-verified against current docs.*

4. **`env.sh` is now partly redundant in-container.** Since `GNNC_CACHE_DIR`
   is container-wide and the consumers self-derive, the test panes don't need
   `env.sh`. Integrated terminals still source it for the convenience of
   typing `mlir-opt` directly; bare-metal/CI use still needs it.

## Future interactions and possible directions

Framed as options, not decisions.

- **CMake-generated `lit.site.cfg.py` (slated ~week 2; see
  [lit.cfg.py:7-8](../test/lit.cfg.py#L7-L8)).** LLVM convention: CMake
  generates a `lit.site.cfg.py` in the **build tree** that injects build-tree
  paths and `load_config`s the source `lit.cfg.py`. It does **not** conflict
  with the per-consumer derivation if ownership is split cleanly:
  - Let CMake own exactly what CMake builds (tool dir, and — *hypothesis,
    depends on the week-2 build* — the MLIR core bindings via
    `find_package(MLIR)`).
  - torch-mlir (out-of-tree) and lighthouse (submodule) are not CMake targets,
    so they stay with the env/helper regardless.
  - Keep the source `lit.cfg.py` **dual-mode** (works with *or* without a site
    config, via the `GNNC_CACHE_DIR` fallback) so the editor and the build
    don't bifurcate.
  - Watch the seam: don't let both CMake and the helper encode the MLIR
    bindings path — pick one owner.
  - **Which tree does the extension scan?** lit chains site→source correctly,
    but the *directory you hand lit* decides whether the build-tree site
    config is seen at all. (See extension note below.)

- **Consolidate the path list into one helper.** e.g. an importable
  `gnnc/_stack_paths.py` exposing the 3 dirs; `conftest.py` and `lit.cfg.py`
  import it, `env.sh` shells out (`python -m gnnc._stack_paths --pythonpath`).
  Single source of truth, per-consumer apply-logic preserved. Tradeoff:
  `env.sh` gains a Python invocation at source-time. Lighter alternative:
  share between `conftest.py` + `env.sh` only and let CMake subsume the lit
  side in week 2.

- **The lit-test-extension is vibe-coded** (source:
  github.com/rdadolf/lit-test-extension, installed from
  [.vscode/lit-test-extension.vsix](../.vscode/lit-test-extension.vsix)). It's
  *intended* to delegate discovery to `lit` itself (e.g. `--show-suites` /
  `--show-tests`), which would inherit lit's correct site→source config
  chaining for free. **Not verified this session** which directory it points
  lit at. When the site config lands, confirm the extension discovers from a
  path where lit will find it (build tree) or that the source config stays the
  editor's intended entry point. The `.vsix` is a zip — unzip and read how it
  invokes `lit` to settle this.

## Provenance (what to re-check before trusting)

- **Verified this session:** `containerEnv`/`remoteEnv` semantics (quoted from
  the two docs above); lighthouse is checked out and importable; the three
  consumers' contents; `GNNC_CACHE_DIR` is a Dockerfile `ENV`; the incident
  trace.
- **Stable convention, not re-verified against current docs:** `terminal.
  integrated.env.*` excluded from tests; `defaultInterpreterPath` as fallback;
  LLVM `configure_lit_site_cfg` / `load_config` / build-tree site-config
  placement; settings-scope precedence (workspace > machine).
- **Hypothesis / depends on plans not yet made:** what the week-2 CMake build
  actually builds (and thus which paths it owns); the latent interpreter-scope
  override being harmless.
- **Reported, not independently verified:** `postCreate`/`postStart` running
  before extensions load; the Python-Environments extension misbehaving; how
  the lit extension invokes `lit`.
