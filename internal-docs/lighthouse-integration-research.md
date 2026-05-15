# Lighthouse Integration Research

> Research notes for integrating `llvm/lighthouse` into `gnnc` the Right Way,
> plus friction/feedback items we'd want to send upstream.
>
> Started 2026-05-15. Updated incrementally as research proceeds.
> Repo cloned to `/tmp/lighthouse-research/lighthouse` for reading.

## The one-paragraph answer

Adopt Lighthouse via a `third_party/lighthouse` submodule. Adopt their
YAML-driven pipeline descriptor model. Re-export their ingress / pipeline
/ execution APIs through thin `gnnc` wrappers; write our own
GNN-specific transform-dialect schedule builders modeled on
`lighthouse/schedule/xegpu/mlp_schedule.py`. One concrete prerequisite,
**VERIFIED 2026-05-15 by experiment**: add
`-DMLIR_BINDINGS_PYTHON_NB_DOMAIN=torch_mlir` to our
`tools/build-torch-mlir.sh` and rebuild. This flag is
already used by torch-mlir's release wheels (`setup.py:119`); it
fixes the shared-library name collision (`PyGlobals already constructed`)
that otherwise prevents Lighthouse from importing in our setup. A
scratch rebuild with the flag was confirmed to (1) produce
`_mlir.cpython.so` linking `libnanobind-torch_mlir.so`, (2) allow
`mlir.ir` + `torch_mlir.fx` + `lighthouse.ingress.torch` to co-load in
one process, and (3) run an end-to-end `torch.compile` matmul through
Lighthouse's MLIR backend with a numerically-correct result. (Only
`NB_DOMAIN` is needed; `MLIR_PYTHON_PACKAGE_PREFIX` is already set by
torch-mlir's own `python/CMakeLists.txt`.) Then
upstream a handful of friction items: missing CUDA runtime in eudsl
wheels (highest impact for the broader ecosystem), missing
sparse-tensor + GPU reference recipe (where we can contribute), and
docs cleanups around `schedule:`/`transform:` and the `lh-tune` TODO.

## Table of contents

1. [TL;DR](#tldr-revised-after-deep-investigation) — the bottom line, read first
2. [Source of truth](#source-of-truth) — what we read
3. [Project policy](#project-policy-verbatim-from-readme-upstream-mlir--upstream-lighthouse) — the "no load-bearing code" rule
4. [Top-level layout](#top-level-layout-main-branch) — what's in the repo
5. [Dependency story](#dependency-story-from-pyprojecttoml) — wheels vs. source
6. [RFC summary](#rfc-summary-from-httpsdiscourseslvm-org-t-rfc-mlir-project-lighthouse-86738) — origin discussion
7. [Component-by-component findings](#component-by-component-findings) — deep-dives
8. [Dependency story details](#dependency-story-details)
9. [In-flight work](#in-flight-work-from-git-log---all---oneline)
10. [Open PRs / open issues](#open-prs--open-issues-as-of-2026-05-15)
11. [Wheel compatibility audit](#wheel-compatibility-audit-eudsl--mlir-python-bindings) — eudsl + sparse + CUDA
12. [RFC framing in detail](#rfc-framing-relevant-excerpts-from-discourse-thread)
13. [Empirical: shared-library collision](#empirical-shared-library-collision-between-source-built-mlir-and-torch-mlir) ⭐ key finding
14. [Risks: in-flight churn](#risk-in-flight-churn-that-affects-integration)
15. [Gap analysis](#gap-analysis-gnnc-today-vs-lighthouse-today) — gnnc vs Lighthouse component table
16. [Friction / feedback log](#friction--feedback-log-for-upstream) — what to send upstream
17. [Integration recipe](#integration-recipe-adopting-lighthouse-the-right-way) — step-by-step
18. [Worked example: xegpu MLP schedule](#worked-example-an-xegpu-mlp-schedule-the-closest-analog-to-what-wed-write)
19. [The canonical integration template](#the-canonical-integration-template-from-examplesxegputorchmatmulpy) ⭐ structural model for `gnnc`
20. [Path C](#path-c-lh-opt-subprocess-last-resort-not-recommended) — fallback
21. [Commit pin candidates](#lighthouse-commit-pin-candidates)
22. [Final synthesis](#final-synthesis) — actionable summary

## TL;DR (revised after deep investigation)

**The state of Lighthouse:**

- **〔fact〕** ~4,800 lines of Python on `main`, three CLI tools (`lh-opt`,
  `lh-run`, `lh-tune`) plus a `kernel_bench` end-to-end driver, torch ingress
  via FX importer, XeGPU autotuning, KernelBench integration, YAML-driven
  pipeline descriptors. Active development by rengolin, rolfmorel, adam-smnk,
  tkarna, charithaintc. Most recent commit dated 2026-05-14.

- **〔fact〕** Project is a wheel consumer (eudsl + torch-mlir-release), not
  a source-builder. They pin LLVM via the wheel version string
  (`mlir-python-bindings==20260503+37e0109a6`). Their nightly cadence is
  one LLVM commit pin per day on average.

**The integration we want:**

- **〔fact〕** Lighthouse provides ~80% of the infrastructure we sketched in
  `gnnc/harness/`: ingress (`MLIRBackend` as a `torch.compile` backend),
  YAML pipeline descriptors, transform-dialect schedule helpers, execution
  engine wrapping, autotuning. **Adopting it would let us delete almost all
  of our current harness stubs and focus on the parts that are GNN-specific.**

**The actual blocker:**

- **〔fact〕 - HIGH CONFIDENCE** A **shared-library naming collision** between
  our locally-built MLIR and locally-built torch-mlir prevents Lighthouse
  from importing in-process under our current setup. Both source-builds
  produce `libnanobind-mlir.so` and `libMLIRPythonSupport-mlir.so` (same
  SONAMEs), each with their own `PyGlobals` C++ singleton. Lighthouse's
  flow imports both libraries into one process (`from torch_mlir import fx`
  then `from mlir import ir`), and the second instance trips
  `assert(!instance)` in PyGlobals.

  **The released wheels avoid this**: torch-mlir's wheel ships
  `libnanobind-torch_mlir.so` and `libMLIRPythonSupport-torch_mlir.so`
  (suffixed). They're built that way deliberately so torch-mlir and
  mlir-python-bindings can co-exist in one Python process. **Our source
  build of torch-mlir does not enable this rename.**

  Verified empirically: `readelf -d` of the wheel's `_mlir.cpython.so`
  shows `NEEDED libnanobind-torch_mlir.so`, while our source build
  shows `NEEDED libnanobind-mlir.so`. The torch-mlir CMake has
  `MLIR_PYTHON_PACKAGE_PREFIX=torch_mlir.` but our build script doesn't
  pass a `MLIR_BINDINGS_PYTHON_NB_DOMAIN` override or equivalent that
  triggers the SONAME rename. We can either find the right flag, or
  switch to wheels.

**The other meaningful gap:**

- **〔fact〕 - HIGH CONFIDENCE** `libmlir_cuda_runtime.so` is **absent from
  every eudsl-distributed wheel** (both `mlir_python_bindings` and the
  bigger `mlir_wheel`). Verified by direct wheel inspection. This is the
  CUDA-cuSPARSE bridge we'd need at execution time. Lighthouse's wheel-only
  story is structurally incomplete for NVIDIA + sparse_tensor users.

**The recommendation:**

- **〔thought〕** **Path A is the right choice.** Stay on source-build,
  add two CMake flags to torch-mlir build, pin Lighthouse as a submodule.
  Total cost: ~1 day of integration work, with high confidence based on
  the empirical findings below. Express our compiler pipelines as
  YAML recipes that compose Lighthouse's bundled CPU pieces
  (`bufferization.yaml`, `llvm_lowering.yaml`) with our own GNN-specific
  Python schedules (modeled on `lighthouse/schedule/xegpu/mlp_schedule.py`).

  **Path B (hybrid: wheels + CUDA carve-out)** remains the fallback if
  Path A turns out blocked. Total cost would be similar but with the
  CI penalty of also maintaining a small CUDA-runtime build.

- **〔thought, upgraded after empirical investigation〕** **Preferred**:
  stay on full source-build, add **two CMake flags** to
  `tools/build-torch-mlir.sh`:
  `-DMLIR_BINDINGS_PYTHON_NB_DOMAIN=torch_mlir
   -DMLIR_PYTHON_PACKAGE_PREFIX=torch_mlir`.
  These are the same flags torch-mlir's release-wheel `setup.py:119`
  passes; they disambiguate the SONAMEs that currently collide. Cost:
  one 10-minute rebuild. Then everything else is the hybrid path
  *minus* the wheel switch — we keep our LLVM commit control, we
  already have `libmlir_cuda_runtime.so`, and Lighthouse just works.

**The upstream feedback (in priority order):**

1. CUDA runtime missing from eudsl wheels — file at llvm/eudsl. **HIGH**.
2. `MLIRBackend` rejects dynamic shapes — discussion at llvm/lighthouse.
3. `schedule:` vs `transform:` synonymy in YAMLs — docs issue.
4. `lighthouse/workload/runner.py` is dead — file delete.
5. `lh-tune` documentation TODO — docs issue.
6. CLI naming inconsistency (`kernel_bench` vs `lh-*`).
7. Contribute back: sparse-tensor + GPU reference recipe once we have
   one working.

(Detailed analysis, gap table, friction log, and integration recipe in
the body. **Final Synthesis** at the bottom remains the actionable
summary.)

## The mental model: two relationships, one satellite

The single most-misread point. When people say "Lighthouse is a starting
point you fork and build on," they conflate two *separate* relationships
your project has with the MLIR ecosystem. Keeping them distinct is the
whole game.

**Relationship 1 — to Lighthouse's Python harness (consume it).**
Lighthouse's ingress / pipeline / recipes / execution are pure Python
that operate at the *recipe and pass-pipeline level*. No load-bearing
code. You consume this by **submoduling Lighthouse** (upstream directly;
fork only when you must carry a patch) and writing your code in `gnnc/`,
*not* inside the submodule. Keeping your code out of the submodule tree
is what makes "the delta" legible — you can always tell what's yours to
contribute back vs. theirs.

**Relationship 2 — to your `gnn.*` dialect (it is a separate satellite).**
A dialect is load-bearing code. By Lighthouse's own no-load-bearing-code
rule it does **not** go into upstream Lighthouse — and by the same logic
you should not bury it inside your fork of Lighthouse either. It lives as
an **out-of-tree MLIR project** that builds its own `gnnc-opt` against
`third_party/llvm-project` at a pinned commit. This is the
IREE / TPP-MLIR / CIRCT "satellite" pattern, and it is exactly what the
RFC's Amini/Rengolin exchange was protecting against folding into
Lighthouse.

**Where they meet:** the recipe boundary, not the codebase. Lighthouse's
YAML recipes can name any registered pass or `-opt` binary as a stage
(`pass: my-gnn-fusion`, or a `transform:` schedule invoking your passes).
So the dialect and Lighthouse interoperate through the pipeline interface
and never need to be the same build.

**Three repos, two upstreaming directions:**

| Repo | Holds | Upstreaming target |
|---|---|---|
| `llvm/lighthouse` (submodule) | generic harness, recipes — never dialects | generic recipes/fixes → PR back to `llvm/lighthouse` |
| `gnnc` (this repo) | `gnnc/` Python + `gnn-dialect/` C++ + recipe YAMLs | — (the integration point) |
| `llvm/llvm-project` (submodule) | MLIR core | sparse-tensor lowering patterns we discover → PR to MLIR |

The `gnn.*` dialect itself most likely has no upstream home (MLIR core is
unlikely to take a domain-specific GNN dialect — **〔guess〕**); the
satellite is probably its permanent residence. The *contributions* that
flow back are: generic Lighthouse recipe/harness improvements, and
sparse_tensor dialect lowering patterns.

Recommended on-disk shape:

```
gnnc/
├── third_party/
│   ├── llvm-project/     submodule, pinned   (already present)
│   ├── torch-mlir/       submodule, pinned   (already present)
│   └── lighthouse/       submodule, pinned   (this work — upstream, not a fork yet)
├── gnn-dialect/          out-of-tree MLIR dialect: gnn.* ops, lowerings, gnnc-opt
├── gnnc/                 Python: thin re-exports of lighthouse + our schedules/recipes
└── ...
```

Rule of thumb: **submodule, don't vendor; keep your code beside it, not
inside it; the dialect is never part of Lighthouse.**

## Notes file convention (kept for reference)

This file is the running scratchpad. As sections get long, I'll keep
updating the TL;DR and the §Final Synthesis at the bottom. Anything
labeled **FEEDBACK:** is a candidate to file upstream as an issue or send
via the RFC thread.

---


## Source of truth

- Repo: <https://github.com/llvm/lighthouse>
- RFC: <https://discourse.llvm.org/t/rfc-mlir-project-lighthouse/86738>
- Latest commit at time of clone: `455d61c BF16 matmul from KernelBench working (#145)` (today)
- Branches:
  - `main` (active)
  - `kb` — kernel bench feature work
  - `lh-xegpu-autotuning` — XeGPU autotuning experiments
  - `users/Groverkss/python-bindings`
  - `users/rolfmorel/{autotuning,kernelbench-ingress,lit-cleanup,rm-python,xegpu-ir-tune}`

The `harness` branch referenced in README §Current Status is no longer in
`branch -a` output. Either renamed or removed after merge. **〔hypothesis〕** the
harness work landed in `lighthouse/{pipeline,schedule,transform,tune,execution,workload}`
on main.

## Project policy (verbatim from README §"Upstream MLIR / upstream Lighthouse")

> One key point in the proposal was to not hold "load bearing" code in this
> repository, but instead, upstream it to MLIR proper and use it here.
>
> It should be fine to have schedule descriptions, aggregation transforms and
> passes that use the upstream MLIR transforms and passes, but we should not
> add actual transforms, dialects and passes here to complement the MLIR story.

The five stated chronological purposes:

1. Test and validate existing assumptions in upstream MLIR.
2. Find common patterns on pipelines, propose merging/reusing upstream code.
3. Once common patterns are detected, discuss/agree on dialect design, canonical
   shapes, and common invariants.
4. Build a solid base for downstream forks to build on, easing upstream of the
   delta.
5. Eventually, the seed for official upstream tooling like Clang is to LLVM.

> Note for `gnnc`: we are squarely in the "downstream fork" category once we
> introduce a `gnn.*` dialect. The five-point purpose list confirms that
> forking is an expected outcome, not a violation.

## Top-level layout (main branch)

```
lighthouse/                  # ~4800 lines of Python
├── dialects/                # Dialect *extensions* (not new dialects), 31 lines
│   ├── dialect_base.py
│   ├── smt_ext/             # SMT dialect extension
│   └── transform/           # Transform dialect extension
├── execution/               # JIT execution wrapper, ~535 lines
│   ├── init.py              # ExecutionEngine setup
│   ├── memory_manager.py    # buffer/memref interop
│   └── runner.py            # entry point
├── ingress/                 # ~1785 lines
│   ├── mlir_gen/            # generate-MLIR-from-scratch (matmul, MLP, softmax payloads)
│   └── torch/               # PyTorch → MLIR (compile.py 384, importer.py 254)
├── pipeline/                # YAML-driven pipeline descriptors, ~759 lines
│   ├── descriptor.py        # 295 lines
│   ├── driver.py            # 202 lines
│   ├── stage.py             # 209 lines
│   └── descriptors/*.yaml   # bufferization, cleanup, llvm_lowering, ...
├── schedule/                # Named transformation pipelines, ~601 lines
│   ├── bufferization.py
│   ├── tiling.py
│   ├── packing.py
│   ├── vectorization.py
│   ├── x86/                 # x86-specific schedules
│   └── xegpu/               # XeGPU-specific schedules + autotuning params
├── transform/               # Python helpers over MLIR transform dialect, ~315 lines
├── tune/                    # Autotuning machinery, ~364 lines (trace.py 321)
├── utils/                   # MLIR/torch/numpy interop, ~380 lines
└── workload/                # Workload-running abstraction, 135 lines

tools/                       # CLI entry points
├── kernel_bench             # KernelBench benchmarking
├── kernel_bench.yaml
├── lh-opt                   # opt-tool wrapper
├── lh-run                   # execution wrapper
└── lh-tune                  # autotuning wrapper

examples/                    # cpu, end-to-end, execution, feed-forward-mpi,
                             # ingress, llama, mlir, schedule, xegpu

test/                        # lit-based: dialects, opt, run, transform
```

## Dependency story (from pyproject.toml)

```toml
[project]
requires-python = ">=3.10,<3.13"    # bounded by torch-mlir's packaging
dependencies = [
    "mlir-python-bindings==20260503+37e0109a6",   # pinned LLVM via wheel
    "pyyaml>=6.0",
]

[project.optional-dependencies]
ingress_torch_mlir = [
    "torch-mlir==20260326.763",
    "ml_dtypes",
]
ingress_torch_cpu    = ["torch==v2.9.1+cpu",      "lighthouse[ingress_torch_mlir]"]
ingress_torch_nvidia = ["torch==2.9.1",            "lighthouse[ingress_torch_mlir]"]
ingress_torch_rocm   = ["torch==2.9.1+rocm6.4",    "pytorch_triton_rocm", ...]
ingress_torch_xpu    = ["torch==2.9.1+xpu",        "pytorch_triton_xpu", ...]
runtime_mpich        = ["mpi4py", "mpich"]
runtime_impi         = ["mpi4py", "impi-rt"]

[tool.uv]
conflicts = [[{extra="ingress_torch_cpu"}, ..., {extra="ingress_torch_xpu"}]]

[tool.uv.sources]
mlir_python_bindings  = { index = "eudsl" }
torch                 = { index = "pytorch" }
pytorch_triton_xpu    = { index = "pytorch" }
pytorch_triton_rocm   = { index = "pytorch" }
torch_mlir            = { index = "torch_mlir" }

[[tool.uv.index]]
name = "eudsl"
url  = "https://llvm.github.io/eudsl"

[[tool.uv.index]]
name = "torch_mlir"
url  = "https://github.com/llvm/torch-mlir-release/releases/expanded_assets/dev-wheels"
```

Key implications for `gnnc`:

- **〔fact〕** Lighthouse's LLVM is pinned to commit `37e0109a6` (2026-05-03) via
  the `mlir-python-bindings==20260503+37e0109a6` wheel version. Their torch-mlir
  is pinned to `20260326.763`. **Our LLVM and torch-mlir submodules are
  considerably newer** — we built against current torch-mlir master to get the
  FX importer behavior we wanted.
- **〔hypothesis〕** Adopting Lighthouse's wheel-only model would obviate our
  source build entirely **if** the wheels expose the dialects and passes we
  need (sparse_tensor especially). This needs verification — see §Compatibility
  audit.
- **〔fact〕** Their conflict-extras pattern (`tool.uv.conflicts`) is cleaner than
  what we have in `pyproject.toml` and worth adopting regardless of integration
  outcome.

## RFC summary (from <https://discourse.llvm.org/t/rfc-mlir-project-lighthouse/86738>)

**〔fact〕** Core motivation (verbatim from the RFC thread):
"upstream dialects become hollow, with weaker semantics and no canonical form."
Lighthouse exists to give MLIR a fitness function — an end-to-end pipeline that
exercises dialects, transforms, and lowerings.

**〔fact〕** The three stated parts (Ingress / Scheduler / Runtime) match the
on-disk layout. The "no load-bearing code" rule is hardened by Mehdi Amini's
challenge in the thread: if dialects move into Lighthouse, it becomes
"a dependency chain that no downstream will be able to use," fragmenting MLIR
similarly to IREE/TPP-MLIR.

**〔fact〕** Outcome of LLVM Project Council review (2025-07-17): repo created
under the `llvm` org **outside** the monorepo (rejected incubator status).
Repo went live 2025-08-01, so Lighthouse is ~10 months old at time of this
research.

**〔fact〕** Key participants in the thread (relevant to whom we'd interact
with upstream): rengolin (Renato Golin), nicolasvasilache (Nicolas Vasilache),
rolfmorel (Rolf Morel), banach-space, javedabsar, matthias-springer, asiemien,
dcaballe, ftynse (Alex Zinenko). nicolasvasilache and ftynse are core MLIR
maintainers; banach-space has touched sparse-tensor work upstream; rolfmorel
appears as the primary day-to-day contributor in the repo's recent PRs.
Steering body: Tensor Compiler Design Group.

**〔hypothesis〕** Our use case sits in their wheelhouse: sparse_tensor is the
dialect we'd most want to exercise, and banach-space + nicolasvasilache are
known sparse-tensor contributors. We are likely to find a receptive audience
for sparse-related friction reports.

## Component-by-component findings

### Ingress (`lighthouse.ingress.torch`)

**〔fact〕** Two entry points:

- `import_from_model(model, sample_args, dialect, ir_context)` — wraps
  `torch_mlir.fx.export_and_import` and returns either a string or an
  `ir.Module`. Output dialects: `linalg-on-tensors`, `torch`, `tosa`. The
  function-level API is exactly what `gnnc/ingress/` would want to call.

- `import_from_file(filepath, model_class_name="Model", init_args_fn_name,
  sample_args_fn_name, ...)` — the KernelBench-style convention: a `.py` file
  defining a `Model` class plus `get_inputs()` / `get_init_inputs()`
  functions. Module is loaded with `importlib.util`, instantiated, then passed
  to `import_from_model`.

**〔fact〕** `lighthouse.ingress.torch.compile.MLIRBackend` is a
`torch.compile(backend=...)` callback class. It:

1. Imports model via FX importer to MLIR (linalg-on-tensors by default).
2. Preprocesses the entry function: marks it private (enables more rewrites)
   and moves results to arguments via `bufferization.materialize_in_destination`
   (sidesteps a bufferization limitation).
3. Hands the module to user-supplied `fn_compile(ir.Module) -> ir.Module`.
4. Wraps the compiled module in a `JITFunction` (`mlir.ExecutionEngine` +
   buffer allocation + packed-arg marshalling).

```python
# usage pattern
@torch.compile(
    dynamic=False,
    backend=cpu_backend(lower_to_llvm, dialect=TargetDialect.LINALG_ON_TENSORS),
)
class Model(nn.Module): ...
```

`gpu_backend(fn_compile, device, ...)` is the same thing for cuda/rocm/xpu
(it just routes the device through).

**FEEDBACK** (low/med priority): `MLIRBackend.is_symbolic` rejects dynamic
shapes outright with `ValueError("Dynamic shapes are not supported - consider
using 'torch.compile(..., dynamic=False)')`. For GNN, edge_index has variable
`num_edges` so dynamic shape support is critical. Would be worth a
conversation about extending — either as upstream contribution or pattern we
need to add. Not a blocker for v0 (we can specialize per dataset).

**FEEDBACK** (med priority): the `move_results_to_args` workaround says
"Current bufferization can't handle return op fed by new tensor values created
using 'materialize_in_destination' op (missing region branch interface)." That
is an upstream bufferization gap. If it gets fixed, this workaround becomes
dead code. Worth flagging.

### Pipeline subsystem (`lighthouse.pipeline`)

**〔fact〕** Pipeline-as-YAML is the headline abstraction. A pipeline file
looks like:

```yaml
Pipeline:
  - include: bufferization.yaml             # compose other pipelines
  - pass: convert-linalg-to-loops           # raw MLIR pass
  - pass: "one-shot-bufferize{function-boundary-type-conversion=identity-layout-map bufferize-function-boundaries=true}"
  - transform: my-schedule.py[gen=create_schedule]{opt1=val opt2=val}
  - transform: my-schedule.mlir
  - schedule: tiling.py[gen=tile_ops]{target_op=linalg.fill tile_sizes=[1,1,1]}
```

**〔fact〕** Four descriptor *types* (the YAML map key), determined by
`Descriptor.is_*()` methods:

| Key in YAML | Required basename form | Dispatch in driver |
|---|---|---|
| `pass`   | bare pass name with optional `{opts}` | `PassStage` (uses `mlir.passmanager.PassManager`) |
| `transform` | `.py` (with `gen=fn_name`) or `.mlir` | `TransformStage` (uses transform dialect) |
| `include` | `.yaml` | recursively parses, flattens stages |
| `schedule` | `.py` or `.mlir` | (treated as `transform` via fall-through file-extension check) |

**FEEDBACK** (low priority but irritating): `schedule:` and `transform:` are
synonymous because `Descriptor.is_transform()` returns True for both — the
`if self.type == "transform"` early-return is False for `type == "schedule"`,
but the file-extension fallback (`.py` or `.mlir`) catches it and sets
`self.type = "transform"`. The official YAMLs use `schedule:` everywhere
(`examples/end-to-end/KernelBench/schedules/x86_64/matmul/*.yaml`) while the
README documents `transform:`. **Either consolidate to one term, or document
both explicitly.** This is a clarity bug, not a behavior bug.

**〔fact〕** Argument syntax: `[arg1=val1,arg2=val2]` for "args" (passed
positionally / to Python `gen=` function as kwargs), `{opt1=val opt2}` for
"opts" (passed to MLIR passes via PassManager options-string).
`_string_to_type` auto-parses int/float/bool/list. Lists use either
`[v1,v2]` or `v1,v2`.

**〔fact〕** Bundled YAML descriptors (`lighthouse/pipeline/descriptors/`):
`bufferization.yaml`, `bufferization_cleanup.yaml`, `cleanup.yaml`,
`llvm_lowering.yaml`. Reusable building blocks.

**〔fact〕** Three drivers:

- `PipelineDriver(ctx)` — base, accepts stages programmatically.
- `TransformDriver(schedules: list[ir.Module])` — for sequences of
  already-loaded transform modules.
- `CompilerDriver(filename, stages=[])` — high-level facade. Owns context,
  loads payload via `import_mlir_module`, registers Lighthouse dialect
  extensions, supports `add_stages()` and `run(print_after_all=...)`.

Pattern from `tools/lh-run` and `tools/kernel_bench`:

```python
driver = CompilerDriver(mlir_file)
driver.make_function_callable(entry_point)   # adds llvm.emit_c_interface
driver.add_stages(user_pipeline_yaml_paths)
driver.add_stage(Descriptor("convert-linalg-to-loops"))
driver.add_stage(Descriptor("llvm_lowering.yaml"))
optimized = driver.run(print_after_all=...)
runner = Runner(optimized)
runner.execute(payload_function_name=entry_point, host_input_buffers=...)
```

**〔fact〕** Pipelines compose by `include:`-ing each other. The
`examples/end-to-end/KernelBench/schedules/x86_64/matmul/{f32,bf16}.yaml`
files demonstrate the production pattern: chain `pack_and_tile.yaml` →
register-tiling python schedule → `vectorize.yaml` → `lower.yaml`. dtype
variants differ by a single tunable.

### Schedule subsystem (`lighthouse.schedule`)

**〔fact〕** Python functions that build MLIR transform-dialect modules.
The canonical pattern is:

```python
from lighthouse.schedule import schedule_boilerplate
import lighthouse.transform as lh_transform

def create_schedule(tile_sizes=[32,32], **opts) -> ir.Module:
    with schedule_boilerplate() as (schedule, named_seq):
        target = named_seq.bodyTarget
        ops = lh_transform.match_op(target, ["linalg.matmul"])
        with lh_transform.foreach(ops) as op:
            lh_transform.tile(op, tile_sizes=tile_sizes, fuse_producers=True)
            transform.yield_()
        lh_transform.cleanup(target)
        transform.yield_()
    return schedule
```

`schedule_boilerplate` is a context manager that creates an `ir.Module` with
`transform.with_named_sequence`, opens a `transform.named_sequence` op with
the right arg/result types, and sets the insertion point inside it.

**〔fact〕** Per-target subdirectories: `schedule/x86/` (register tiling,
cache tiling, pack lowering, AVX-flavored matmul) and `schedule/xegpu/`
(MLP/softmax for Intel XeGPU + autotuning parameter selector). General ones:
`bufferization.py`, `tiling.py`, `packing.py`, `vectorization.py`,
`linalg.py`, `hoisting.py`, `func.py`.

**〔hypothesis〕** Our path: add `gnnc/schedule/sparse_gnn/` with our own
`gcn.py`, `sage.py`, `gat.py` schedules that follow this exact pattern.

### Transform subsystem (`lighthouse.transform`)

**〔fact〕** Thin Pythonic wrappers around raw MLIR transform-dialect ops.
Key files:

- `matchers.py` (27 lines) — `match_op(target, op_name | interface)`.
- `foreach.py` (75 lines) — context-manager wrapping `transform.ForeachOp`
  with `__enter__`/`__exit__` managing the insertion point. Cleanly Pythonic.
- `tiling.py` (87 lines) — `tile(target, tile_sizes, fuse_producers, ...)`
  combines `structured.FuseOp` / `structured.TileUsingForOp` /
  `loop.LoopPeelOp` / `loop.loop_unroll`.
- `cleanup.py` (41 lines) — `cleanup(target)` = `apply_cse` +
  `apply_patterns_canonicalization`. `simplify_vector_ops`,
  `flatten_vector_ops` are vector-flavored cleanups.
- `vectorization.py`, `packing.py`, `hoisting.py` — domain-specific helpers.

**〔fact〕** `lighthouse.dialects.transform.transform_ext` — they have at
least one dialect extension on the transform dialect (e.g.,
`wrap_in_benching_func` used by `Runner.get_bench_wrapper_schedule`).

**FEEDBACK** (low priority): the docstring in `transform/foreach.py` says
"Nested multiple entry is not supported," meaning you can't reuse the same
`foreach` instance multiple times. It's an artifact of storing the
`insertion_point` on the instance. Minor papercut but worth noting.

### Execution subsystem (`lighthouse.execution`)

**〔fact〕** `Runner` (`execution/runner.py`) wraps `mlir.ExecutionEngine` for
benchmarking. Key features:

- Optional `mem_manager_cls=GPUMemoryManager` — allocates device buffers via
  `gpu.alloc`/`gpu.dealloc`/`gpu.memcpy` ops emitted into the payload.
  Falls back to numpy→memref descriptor for CPU.
- `benchmark()` calls a pre-wrapped `__benchmark` function that uses
  `rtclock` (so the payload must be wrapped with `get_bench_wrapper_schedule`
  before lowering).
- `execute()` for one-shot calls.
- `argument_access_callback` hook for reading back GPU outputs to the host.

**〔fact〕** `MemoryManager` is an ABC. `GPUMemoryManager` is the only
concrete subclass on main, and works by emitting Python-callable functions
like `gpu_alloc_2d_f32`, `gpu_dealloc_1d_f64`, `gpu_copy_2d_bf16` into the
payload at lower time (`emit_memory_management_funcs`).

**〔fact〕** `KernelArgument` (`execution/init.py`) parses shape strings like
`256x512xf32xrnd` into typed numpy arrays for benchmark inputs.

**FEEDBACK** (med priority): the `Workload` class is referenced from
`lighthouse/workload/runner.py` but doesn't exist on main — PR #96
("Remove Workload object") removed the class but left
`lighthouse/workload/runner.py` with dangling imports. **This file is dead
code.** Should be deleted or the imports fixed.

### Tune subsystem (`lighthouse.tune`)

**〔fact〕** Autotuning via upstream `transform.tune` dialect + SMT dialect
for constraints. Workflow (from `tools/lh-tune`):

1. User authors a transform-dialect schedule containing `transform.tune.knob`
   ops and `transform.tune.alternatives` ops, plus SMT-dialect constraints
   inside `lighthouse.dialects.transform.smt_ext.ConstrainParamsOp`.
2. `lighthouse.tune.trace.trace_tune_and_smt_ops` walks the IR and produces
   a Python DAG of `Node` subclasses (`Constant`, `Knob`, `Apply`,
   `Predicate`, `Alternatives`, `AlternativesResult`).
3. `lighthouse.tune.enumerate.all_satisfying_assignments` enumerates valid
   knob assignments.
4. `lighthouse.tune.rewrite.set_selected` materializes a concrete schedule
   for each assignment.

**〔hypothesis〕** Beautiful design, but not v0 territory for us. We'd want
this once we have a working pipeline and start optimizing.

### Dialects subsystem (`lighthouse.dialects`)

**〔fact〕** `lighthouse.dialects` contains **dialect extensions**, not new
dialects — consistent with the no-load-bearing-code rule. `dialect_base.py`
(15 lines) and `__init__.py` (16 lines) provide a `register_and_load()`
entry point. Two extensions: `smt_ext` (for autotuning constraints) and
`transform/` (for `wrap_in_benching_func` and similar transform-dialect
helpers).

**〔hypothesis〕** Our `gnn.*` dialect would be the moment we leave the
"no load-bearing code" envelope and become a satellite, per the project doc.

### CLI tools (`tools/`)

**〔fact〕** Three CLIs plus a benchmarking driver:

- `lh-opt` — `lh-opt --stage=stage1 --stage=stage2 file.mlir`. Each stage
  can be a pass name, a `.yaml` pipeline, a `.py` schedule, or a `.mlir`
  transform schedule. Pure compile, no execution.
- `lh-run` — adds JIT execution and benchmarking on top of `lh-opt`. Takes
  `--input-shape=256x512xf32xrnd,512x1024xf32xrnd` and `--entry-point=foo`.
- `lh-tune` — applies the tune-DAG enumeration; prints concrete schedules.
- `kernel_bench` — end-to-end: PyTorch model file → MLIR → optimize → run.

**FEEDBACK** (low priority): the CLI names are inconsistent — `lh-opt`,
`lh-run`, `lh-tune` (dashed `lh-` prefix) vs `kernel_bench` (snake_case, no
prefix). Pick one convention. Probably `lh-kernel-bench` to be consistent.

**FEEDBACK** (med priority): `tools/lh-tune` README says "TODO: Write short
doc and examples on how to use." The actual mechanism is interesting but
undocumented.

### Examples (`examples/`)

**〔fact〕** `examples/ingress/torch/compile_model.py` is the canonical
"how to integrate" demo — a 149-line file that shows `@torch.compile(
backend=cpu_backend(lower_to_llvm))` end to end, including the user-supplied
`lower_to_llvm` PassManager-builder. **This is the file to copy for our
v0 integration.**

**〔fact〕** `examples/end-to-end/KernelBench/test_kernel_bench.py` shows
production usage: subprocess-invokes the `kernel_bench` CLI for each test
case, parses GFLOPs from output.

**〔fact〕** `examples/llama/` exists with `ref_model.py`,
`torch_ingress.py`, `test_llama3.py` — this is a recent push to validate
the framework on a real model (llama3). Good signal that they're scaling
beyond matmul benchmarks.

**〔fact〕** `examples/xegpu/` is the most actively developed: matmul, MLP,
softmax, autotuning via both genetic algorithm and grid search.
**Intel XeGPU is the production-target focus of the project right now.**

**〔hypothesis〕** This means the CUDA/AMD code paths are *less* exercised
in CI. Our sparse-GPU path will need to validate that the
`MLIR_ENABLE_CUDA_CUSPARSE` etc. integration works against their wheels —
their CI may not catch breakage there. We should plan to contribute CUDA
tests upstream if we encounter gaps.

### Tests (`test/`)

**〔fact〕** lit-driven, with a small set of cross-cutting checks:

- `test/opt/pipeline-check.mlir` — same payload run through `.mlir`,
  `.yaml`, `.py` stages, asserts equivalence. **This is the canonical
  contract for the four descriptor types.**
- `test/run/pipeline-check.mlir` — same for `lh-run`.
- `test/dialects/transform_ext.py` — tests the lighthouse transform
  extensions.
- `test/transform/test_foreach.py` — unit-style test for the foreach
  context manager.

Note `lit.local.cfg` files gate by REQUIRES (e.g., `REQUIRES: torch`,
`REQUIRES: kernel_bench`) so a partial install only runs what's possible.

## Dependency story details

**〔fact〕** Lighthouse depends on the following upstream wheel projects:

- **eudsl** (<https://github.com/llvm/eudsl>): pre-built MLIR Python
  bindings. The wheel `mlir-python-bindings==20260503+37e0109a6` is keyed on
  the LLVM commit it was built against — version string encodes
  `<date>+<llvm-sha>`. Wheels are hosted at
  <https://llvm.github.io/eudsl> (a `flat` index per their pyproject.toml).
- **torch-mlir** (<https://github.com/llvm/torch-mlir-release>): pre-built
  torch-mlir wheels. Version `20260326.763` is the wheel they pinned to.

**〔hypothesis〕** Implications for `gnnc`:

- If we switch to wheels: no source build, faster CI, but we pin to whatever
  LLVM commit eudsl built against — which may not include the latest
  sparse_tensor passes we want.
- If we stay on source: we can pick our LLVM commit but pay 30-min build
  cost per LLVM bump, and we diverge from Lighthouse's expected setup.
- Hybrid: use Lighthouse's wheel-based pyproject for *Lighthouse itself* but
  point at our local source-built `mlir` Python bindings via a local install
  override. Needs investigation.

**TODO:** verify whether eudsl wheels include the sparse_tensor dialect
passes (`sparsifier`, `sparse-tensor-rewrite`, etc.) and the GPU runtime
shims (`libmlir_cuda_runtime.so` with cuSPARSE bindings) we depend on.

## In-flight work (from `git log --all --oneline`)

- `kb` branch / `users/rolfmorel/kernelbench-ingress` — KernelBench
  ingress, looks merged in part (`32cd309 Initial Kernel Bench "compiler"`).
- `lh-xegpu-autotuning`, `users/rolfmorel/{autotuning,xegpu-ir-tune}` —
  XeGPU autotuning experiments.
- `users/rolfmorel/lit-cleanup` — test harness cleanup.
- `users/rolfmorel/rm-python` — unclear (workload removal?).
- `users/Groverkss/python-bindings` — unclear (possibly an alternative
  bindings approach).

## Open PRs / open issues (as of 2026-05-15)

**Open PRs:**
- #146 "Add first 40 kernels to KB test" (rengolin, 2026-05-14)
- #116 "[CI] Limit max line length" (adam-smnk, 2026-04-09)

**Open issues:**
- **#139 "Organize the `transform` and `schedule` folders"** (rengolin,
  2026-05-10) — explicit refactor coming. Proposal: keep only
  `foreach`, `match_op`, `schedule_boilerplate`, `create_schedule`,
  `create_named_sequence` in `transform/`; move per-hw schedules under
  `schedule/`. **This will move/rename APIs we'd be importing.**
- #142 "KernelBench benchmarking" — wants public-CI smoke + Intel-internal
  benchmark version. Notes: "with provisions for others to contribute ARM,
  AMD, and NVIDIA testing within their own infrastructure while maintaining
  upstream schedules and tests." **Explicit invitation for NVIDIA
  contributions.**
- #141 "KernelBench target architecture selector" — pre-req for #142.
- #125 "Integrate RL auto-tuner into Lighthouse" — references a workshop
  talk; alternate tuning approach to the existing transform.tune+SMT
  workflow. Speculative for now.
- #122 "Kernel Bench + torch.compile" — unify the `import_from_file`-driven
  `kernel_bench` CLI with the Dynamo-backend `MLIRBackend` path. No PR yet.

**Most active PR authors** (from recent merges): rengolin (Renato Golin,
project lead) drives high-level layout; adam-smnk does ingress / CPU
matmul / x86 work; tkarna and charithaintc focus on XeGPU.
**rolfmorel** authored the autotuning infra and has several user/* branches
still in flight.

## Wheel compatibility audit (eudsl / mlir-python-bindings)

This section answers: **can we use Lighthouse's wheel-only dependency model
for `gnnc`?**

**Method:** downloaded
`mlir_python_bindings-20260514+940242e62-cp312-cp312-manylinux_2_34_x86_64.whl`
(77 MB) and `mlir_wheel-20260514+940242e62-py3-none-linux_x86_64.whl`
(712 MB) and inspected contents.

**〔fact〕** Wheel update cadence: 26 LLVM commit pins in eudsl's index,
most recent dated **2026-05-14 (yesterday)**. Wheels are built nightly.

**〔fact〕** sparse_tensor dialect coverage in
`mlir_python_bindings-*.whl`:

| Component | Present | Path |
|---|---|---|
| Sparse-tensor IR bindings | ✓ | `mlir/_mlir_libs/_mlirDialectsSparseTensor.cpython-*.so` |
| Sparse-tensor passes module | ✓ | `mlir/_mlir_libs/_mlirSparseTensorPasses.cpython-*.so` |
| Python dialect wrapper | ✓ | `mlir/dialects/sparse_tensor.py` |
| Transform-dialect sparse extension | ✓ | `mlir/dialects/transform/sparse_tensor.py` |
| TableGen headers (for downstream extension) | ✓ | `mlir/_mlir_libs/include/mlir/Dialect/SparseTensor/...` |

All 16 sparse-tensor passes are in the wheel:
`sparse-assembler`, `sparse-reinterpret-map`, `pre-sparsification-rewrite`,
`sparsification`, `stage-sparse-ops`, `lower-sparse-ops-to-foreach`,
`lower-sparse-foreach-to-scf`, `sparse-tensor-conversion`,
`sparse-tensor-codegen`, `sparse-buffer-rewrite`, `sparse-vectorization`,
**`sparse-gpu-codegen`**, `sparse-storage-specifier-to-llvm`,
`sparsification-and-bufferization`, `sparse-space-collapse`,
`lower-sparse-iteration-to-scf`. So the *codegen* side is complete.

**〔fact〕** GPU dialect coverage:

| Component | Present |
|---|---|
| GPU dialect bindings | ✓ `_mlirDialectsGPU.cpython-*.so` |
| GPU passes | ✓ `_mlirGPUPasses.cpython-*.so` |
| NVGPU dialect bindings | ✓ `_mlirDialectsNVGPU.cpython-*.so` |
| AMDGPU dialect bindings | ✓ `_mlirDialectsAMDGPU.cpython-*.so` |

**〔fact〕 — CRITICAL GAP** Runtime libraries shipped in the wheels:

```
libMLIRPythonCAPI.so
libMLIRPythonSupport-mlir.so
libmlir_apfloat_wrappers.so
libmlir_arm_runner_utils.so
libmlir_arm_sme_abi_stubs.so
libmlir_async_runtime.so
libmlir_c_runner_utils.so
libmlir_float16_utils.so
libmlir_runner_utils.so
libmlir_spirv_cpu_runtime.so          # SPIR-V via CPU sim, NOT cuSPARSE
libnanobind-mlir.so
```

There is **no `libmlir_cuda_runtime.so`** in either the
`mlir_python_bindings` wheel or the bigger `mlir_wheel` (712 MB) wheel.
Searched on `cuda` keyword: only Clang headers
(`Cuda.h`, `CudaInstallationDetector.h`, `SemaCUDA.h`) — no runtime objects.

This means: while the wheel **can generate** GPU MLIR (and even
`sparse-gpu-codegen` IR), it **cannot execute** it because the runtime
shim that bridges to cuSPARSE / cuRAND / etc. is absent. To execute, we
need a `libmlir_cuda_runtime.so` built with `MLIR_ENABLE_CUDA_CUSPARSE=ON`,
which requires a CUDA toolkit at MLIR build time — something the eudsl CI
intentionally lacks.

**FEEDBACK** (HIGH priority): file an issue at <https://github.com/llvm/eudsl>
requesting a CUDA-enabled variant. Without it, NVIDIA+sparse users cannot
use the wheel-only flow — they must source-build MLIR with
`MLIR_ENABLE_CUDA_CUSPARSE=ON`. Suggested form: a separate
`mlir_python_bindings_cuda` wheel (or an extra) that ships only the
`libmlir_cuda_runtime.so`, dlopen-loaded.

**〔hypothesis〕** Discussion-worthy: since cuSPARSE is closed-source NVIDIA
code, eudsl may have license/CI constraints preventing them from bundling
it. The fallback is for downstream projects to publish their own
companion wheel. We could be that project.

## RFC framing (relevant excerpts from Discourse thread)

**〔fact〕** Initial hardware focus (verbatim): "Intel and AMD CPUs and
GPUs." NVIDIA was not explicitly named; CUDA was not discussed in the
original thread. **We are an unrepresented use case** by initial scope.

**〔fact〕** The RFC anticipated CMake-based build with submodule fetching,
but the project moved to wheel-based dependencies after launch. The wheel
approach is *not* explicitly debated in the surviving thread excerpts.

**〔fact〕** Downstream contribution model (verbatim): "downstream projects
(such as IREE, TPP, Tile IR, CIRCT) would work together with their
communities to add _common_ recipes as standalone scripts/binaries or
`-opt` pass pipelines." And: "these should not be a replication of their
downstream tests, or a copy of existing MLIR integration tests."
Implication: our contribution mode is **upstream a generic sparse-tensor
GNN reference recipe**, not "make Lighthouse depend on gnnc."

**〔fact〕** sparse_tensor dialect is **not** mentioned in the RFC thread.
Combined with the CUDA gap, sparse+GPU is a genuine novel direction we
could contribute as a recipe.

## Empirical: shared-library collision between source-built MLIR and torch-mlir

This is the most consequential finding from the experimental section. It
materially changes the recommendation in §Final Synthesis.

**Setup:** `tools/env.sh` puts both
`$LLVM_BUILD/tools/mlir/python_packages/mlir_core` (provides `mlir.*`) and
`$TORCH_MLIR_BUILD/python_packages/torch_mlir` (provides `torch_mlir.*`) on
`PYTHONPATH`. Both directories ship their own bundled `_mlir_libs/` with
nanobind-compiled `.so` files.

**Test:** import Lighthouse's torch ingress against this environment.

```bash
$ source tools/env.sh
$ cd /tmp/lighthouse-research/lighthouse
$ python -c "import mlir.ir; from lighthouse.ingress.torch import importer"
RuntimeWarning: nanobind: type '_Globals' was already registered!
python: .../mlir/lib/Bindings/Python/Globals.cpp:50:
       Assertion `!instance && "PyGlobals already constructed"' failed.
Aborted
```

**Diagnosis** (via `readelf -d`):

| Source | `_mlir.cpython.so` NEEDED | Outcome |
|---|---|---|
| Our LLVM build | `libnanobind-mlir.so`, `libMLIRPythonSupport-mlir.so` | local-only OK |
| Our torch-mlir build | `libnanobind-mlir.so`, `libMLIRPythonSupport-mlir.so` | local-only OK |
| **Released torch-mlir wheel (2026-05-14)** | `libnanobind-torch_mlir.so`, `libMLIRPythonSupport-torch_mlir.so` | **co-existence OK** |

So the released wheel uses *renamed* support libraries. Each support library
exports its own `PyGlobals` instance, in its own nanobind type-registry
domain, so the two can coexist in one process. Our local source build of
torch-mlir produces non-renamed support libraries, which collide.

**Why our build doesn't rename:**

`third_party/torch-mlir/python/CMakeLists.txt:12` already sets
`add_compile_definitions("MLIR_PYTHON_PACKAGE_PREFIX=torch_mlir.")`. This
affects compiled C++ code paths that use the macro. **But the upstream
LLVM `mlir/CMakeLists.txt` separately defines:**

```cmake
set(MLIR_BINDINGS_PYTHON_NB_DOMAIN "mlir"
    CACHE STRING "nanobind domain for MLIR python bindings.")
```

— this is the variable that drives the `libnanobind-${suffix}.so` name. It's
a `CACHE STRING`, so a single setting per cache. When torch-mlir builds
out-of-tree against our LLVM build, it inherits the cached `mlir` value,
not `torch_mlir`. We need to override at `cmake` invocation time:

```
cmake ... -DMLIR_BINDINGS_PYTHON_NB_DOMAIN=torch_mlir
```

**This flag is already in torch-mlir's release build path.**
`third_party/torch-mlir/setup.py:119`:

```python
cmake_config_args = [
    ...
    "-DMLIR_BINDINGS_PYTHON_NB_DOMAIN=torch_mlir",
    ...
]
```

`setup.py` is the canonical build path for the release wheels. Our
`tools/build-torch-mlir.sh` does its own out-of-tree CMake invocation
without this flag. **So the released wheels work and our local builds
don't, because we skipped the flag.**

Current cached value in our build (`grep`'d from
`/x/cache/build/torch-mlir/CMakeCache.txt`):

```
MLIR_BINDINGS_PYTHON_NB_DOMAIN:STRING=mlir
MLIR_PYTHON_PACKAGE_PREFIX:STRING=mlir
```

Both are `mlir` (inherited from upstream LLVM CMakeCache defaults). They
should be `torch_mlir`.

**DONE — VERIFIED 2026-05-15.** Added `-DMLIR_BINDINGS_PYTHON_NB_DOMAIN=torch_mlir`
to a scratch out-of-tree configure (build dir
`/x/cache/build/torch-mlir-nbtest`, leaving the canonical
`$TORCH_MLIR_BUILD` untouched), built with `ninja -j6`, exit 0. Results:

1. ✅ `readelf -d .../torch_mlir/_mlir_libs/_mlir.cpython-312-*.so | grep NEEDED`
   shows `libnanobind-torch_mlir.so` and `libMLIRPythonSupport-torch_mlir.so`
   (was `-mlir` before). `libnanobind-torch_mlir.so` and
   `libMLIRPythonSupport-torch_mlir.so` are present in `_mlir_libs/`.
2. ✅ With `PYTHONPATH` pointed at the rebuilt torch-mlir +
   our LLVM `mlir_core`:
   `python -c "import mlir.ir; from torch_mlir import fx; from
   lighthouse.ingress.torch import cpu_backend"` — no PyGlobals assertion.
3. ✅ End-to-end: `@torch.compile(backend=cpu_backend(lower_to_llvm))`
   on a `torch.matmul` model, lowered through Lighthouse's bundled
   bufferization/llvm pipeline, executed via `JITFunction`, returned
   `torch.allclose(ref, out) == True`.

`-DMLIR_PYTHON_PACKAGE_PREFIX=torch_mlir` was **not** needed and **not**
passed — torch-mlir's `python/CMakeLists.txt` already handles the package
prefix via `add_compile_definitions`. Only `NB_DOMAIN` matters, matching
`setup.py:119` exactly.

**Net: Path A is no longer a hypothesis — it is verified to work.** The
remaining integration work is mechanical (submodule, re-exports, recipe
YAMLs, GNN schedules). The only build-script change required is the
single `-D` flag in `tools/build-torch-mlir.sh`.

**FEEDBACK** (low/med priority — actually a docs/tooling issue rather than
a bug): torch-mlir's `python/CMakeLists.txt` sets
`MLIR_PYTHON_PACKAGE_PREFIX=torch_mlir.` for compiled C++ code paths but
does NOT propagate it to the CMake cache variable
`MLIR_BINDINGS_PYTHON_NB_DOMAIN` (which drives SONAMEs). The result is
that anyone following torch-mlir's "Out-of-Tree" build doc and not using
`setup.py` produces a torch-mlir that can never coexist with
mlir-python-bindings in one process. Worth filing as an issue at
`llvm/torch-mlir` (small ask: either add the line to
`python/CMakeLists.txt` so it's automatic, or document that
`-DMLIR_BINDINGS_PYTHON_NB_DOMAIN=torch_mlir` is required).

## Risk: in-flight churn that affects integration

| Risk | Source | Impact on us |
|---|---|---|
| `transform/` → `schedule/` reorganization | #139 | If we depend on `lighthouse.transform.tile` etc., those imports may move. Mitigation: depend only on the "core infrastructure" subset (`foreach`, `match_op`, `schedule_boilerplate`) which #139 says will stay. |
| `kernel_bench` + `torch.compile` unification | #122 | If we ape both code paths, the unified API may differ. Mitigation: pick **one** path (we should pick the `torch.compile` Dynamo-backend route; it's more general). |
| RL auto-tuner alongside existing tune subsystem | #125 | Two competing autotuning frameworks may emerge. Mitigation: defer autotuning to v1+; not v0 concern. |
| Wheel pin churn (LLVM commit advances nightly) | n/a | Lighthouse pins to a specific eudsl wheel build (currently 2026-05-03). When their pin moves, sparse-tensor pass options may change. Mitigation: pin to a known-good LLVM commit, advance deliberately. |
| Possible package-API instability | the repo is 10 months old, has had at least three refactors (`b97d355`, `3c4631a`, `8a58444`) | Public Lighthouse APIs are not stable. Mitigation: contain coupling — wrap their APIs in a thin `gnnc.harness` layer, swap implementations behind it. |

## Gap analysis: `gnnc` today vs `lighthouse` today

**Current `gnnc` (186 lines of Python, all stubs):**

```
gnnc/
├── __init__.py
├── cli.py                  # placeholder `gnnc run` that prints config
├── paths.py                # DATA_DIR, CACHE_DIR resolution
├── _torch_load_compat.py   # OGB safe-globals shim
├── harness/
│   ├── __init__.py
│   ├── ingress.py          # NotImplementedError
│   ├── recipes.py          # recipe registry (1 stub recipe)
│   ├── runner.py
│   ├── golden.py
│   └── compare.py
├── ingress/                # empty package
└── recipes/                # empty package
```

**Lighthouse (~4,800 lines of Python):**

```
lighthouse/
├── ingress/torch/{compile.py, importer.py}     # ✓ matches our ingress goal
├── pipeline/{descriptor, driver, stage, helper, descriptors/*.yaml}
├── schedule/{tiling, packing, vectorization, bufferization, x86/, xegpu/, ...}
├── transform/{foreach, tile, cleanup, matchers, ...}  # transform-dialect helpers
├── execution/{runner, memory_manager, init}     # ExecutionEngine wrappers
├── tune/{trace, enumerate, rewrite}             # autotuning via SMT
├── dialects/{transform_ext, smt_ext}            # dialect extensions
├── utils/{mlir, torch, numpy, memref, types}
└── workload/                                    # dead, post-removal
```

**Component-by-component overlap:**

| Concern | What `gnnc` has | What Lighthouse has | Verdict for v0 |
|---|---|---|---|
| PyG/PyTorch → MLIR | `harness/ingress.py` stub | `ingress/torch/importer.py` (`import_from_model`, `import_from_file`); `ingress/torch/compile.py` (`MLIRBackend`, `cpu_backend`, `gpu_backend`) | **Consume Lighthouse.** Their importer is exactly what we need. |
| Recipe abstraction | `harness/recipes.py` registry (Python callables, single global dict) | `pipeline/{descriptor, driver, stage}` (YAML-driven; pass/transform/include/schedule keys; PassManager + transform-dialect dispatch) | **Adopt Lighthouse's YAML model.** Our Python-registry pattern is weaker. |
| Pass-pipeline driver | None | `PipelineDriver` / `CompilerDriver` | **Consume Lighthouse.** |
| Transform-schedule helpers | None | `lighthouse.transform.{foreach, match_op, tile, cleanup}` | **Consume Lighthouse, but expect API motion.** Issue #139 will rename. Wrap behind our own thin facade. |
| Execution / benchmarking | `harness/runner.py` (12-line stub) | `execution/runner.py` (251 lines), `GPUMemoryManager`, `KernelArgument` parser | **Consume Lighthouse.** |
| CPU recipes (bufferization, vectorization, llvm lowering) | None | `pipeline/descriptors/*.yaml`, `schedule/{bufferization,vectorization,tiling,packing}.py` | **Consume Lighthouse.** Their `bufferization.yaml`, `llvm_lowering.yaml`, `cleanup.yaml` are general-purpose. |
| GPU recipes | None | `schedule/xegpu/*` (Intel-specific), no NVIDIA | **Need to write.** Our v0/v1 contribution. |
| Sparse-tensor recipes | None | None | **Need to write.** Our entire reason for existing. |
| GNN ingress (PyG-specific) | None | None | **Need to write.** Our domain. |
| Autotuning | None | `tune/` (transform.tune + SMT trace + enumerate) | **Defer.** Not v0. |
| Dialect (`gnn.*`) | None | None — and never will, per their no-load-bearing-code rule | **Our satellite.** Future, post-v0. |
| Golden-output testing | `harness/golden.py`, `compare.py` | (lit tests + KernelBench correctness checks) | **Keep our own; don't replace.** |
| CLI | `gnnc cli.py` stub | `lh-opt`, `lh-run`, `lh-tune`, `kernel_bench` | **Reuse Lighthouse CLIs initially.** Add `gnnc` CLI on top later. |

### Naming and layout collisions

Our current `harness/` structure (with `ingress.py`, `recipes.py`, `runner.py`,
`golden.py`, `compare.py`) is **flatter than Lighthouse's**. Lighthouse uses
subpackages: `ingress/`, `pipeline/`, `execution/`, etc. If we adopt
Lighthouse, our `harness/` becomes ambiguous (is it our wrapper layer? a
duplicate? renamed?).

**〔thought〕** Plan: rename `gnnc/harness/` → `gnnc/` siblings of
Lighthouse's: `gnnc/ingress/` (already exists, empty — wire it up to import
from `lighthouse.ingress.torch` and add PyG-specific rewrites here),
`gnnc/recipes/` (empty — populate with our YAML schedules + Python schedule
builders), and add `gnnc/schedule/` to hold our transform-dialect schedule
builders (analog of `lighthouse/schedule/x86/`). Drop the `harness/` name
or repurpose to mean "the thin compatibility layer we maintain over
Lighthouse APIs that we expect to churn."

## Friction / feedback log for upstream

Ranked by what we'd want to discuss with the Lighthouse maintainers.

### HIGH-priority feedback (real blockers for sparse+CUDA users)

1. **CUDA runtime absent from eudsl wheels.** Both
   `mlir_python_bindings-*.whl` and `mlir_wheel-*.whl` lack
   `libmlir_cuda_runtime.so`. This means anyone targeting NVIDIA hardware
   via MLIR-Python must source-build LLVM with
   `MLIR_ENABLE_CUDA_CUSPARSE=ON`. **Suggested action:** either a
   separate CUDA-enabled wheel variant, or document the source-build
   requirement, or expose a hook to slot in a downstream-built runtime
   library. File at <https://github.com/llvm/eudsl/issues>.

2. **Dynamic shapes hard-rejected in `MLIRBackend`.** `is_symbolic()` raises
   `ValueError("Dynamic shapes are not supported - consider using
   'torch.compile(..., dynamic=False)'")`. Real GNN inputs have
   `num_edges` varying per batch / dataset; specializing per shape is
   wasteful at compile time. **Suggested action:** at minimum, document
   how a downstream `MLIRBackend` subclass can override this; longer-term,
   support dynamic dims at the boundary and let the schedule decide what
   to specialize.

3. **Sparse-tensor + GPU pipeline is an uncovered use case.** Their entire
   GPU story is XeGPU-focused; NVIDIA + sparse_tensor + sparse-gpu-codegen
   is not exercised in CI. **Suggested action:** offer to contribute a
   reference recipe (sparse SpMM lowered via `sparse-gpu-codegen` → cuSPARSE
   wrappers) once we have one working. Confirms #142's invitation for
   external NVIDIA contributions.

### MEDIUM-priority feedback (real ergonomic issues)

4. **`schedule:` vs `transform:` synonymy is undocumented.** The YAMLs in
   `examples/end-to-end/KernelBench/schedules/x86_64/matmul/*.yaml` use
   `schedule:`, but the README/docstrings consistently use `transform:`.
   They work because `Descriptor.is_transform()` falls through on a file
   extension check, not because `schedule:` is an explicit alias. **Pick one
   name or document both.**

5. **`bufferization.materialize_in_destination` workaround in `compile.py`.**
   The comment says: "Current bufferization can't handle return op fed by
   new tensor values created using 'materialize_in_destination' op (missing
   region branch interface)." This is an upstream MLIR gap that
   Lighthouse is papering over. **Worth tracking the upstream fix and
   eventually deleting the workaround.**

6. **`lighthouse/workload/runner.py` is dead.** It imports
   `from lighthouse.workload import Workload`, but `Workload` was removed
   in PR #96. The file should be deleted or its imports fixed.

7. **`lh-tune` is documented as TODO.** `tools/README.md` says: "TODO: Write
   short doc and examples on how to use." For a feature this sophisticated,
   the docs gap is a real adoption blocker.

8. **`kernel_bench` is snake_case; `lh-opt`/`lh-run`/`lh-tune` are
   dash-prefixed.** Inconsistent naming. Maybe `lh-kernel-bench`?

### LOW-priority feedback (papercuts)

9. `transform/foreach.py` instance can't be re-entered; the insertion-point
   state is stored on `self`. Minor issue for advanced patterns.

10. `Descriptor._string_to_type` doesn't handle quoted strings or escape
    sequences; works fine for the current uses but is fragile.

11. The transform-dialect `apply_bundle` walks every pass in a YAML and
    issues one `transform.apply_registered_pass` per pass. For a 9-stage
    bundle, that's 9 separate transform ops. Could be folded into a single
    sub-pipeline op if upstream supported it.

12. Several YAMLs (e.g.
    `examples/end-to-end/KernelBench/schedules/x86_64/matmul/bf16.yaml`)
    differ from sibling YAMLs by exactly one knob (`reg_unroll_k`). They
    cry out for a Jinja-style template or shared base with overrides;
    `include:` is too coarse-grained. **〔thought〕** Worth proposing
    parameter-overrides-on-include as a syntax extension.

## Integration recipe: adopting Lighthouse the Right Way

This is the step-by-step plan, with explicit *gates* the user authorizes.

### Phase 0: Fix the torch-mlir SONAME collision (10-minute experiment)

This is the critical prerequisite — if this doesn't work, Path A is
blocked and we fall back to Path B.

- [user gate] Confirm willingness to rebuild torch-mlir once.
- [ ] Edit `tools/build-torch-mlir.sh` to add two CMake flags:
  ```bash
  cmake -G Ninja -S "$TM_SRC" -B "$BUILD_DIR" \
      ...
      -DMLIR_BINDINGS_PYTHON_NB_DOMAIN=torch_mlir \
      -DMLIR_PYTHON_PACKAGE_PREFIX=torch_mlir \
      ...
  ```
- [ ] `rm -rf $TORCH_MLIR_BUILD; bash tools/build-torch-mlir.sh`
- [ ] Verify:
  - `readelf -d $TORCH_MLIR_BUILD/python_packages/torch_mlir/torch_mlir/_mlir_libs/_mlir.cpython-312-*.so | grep NEEDED` shows `libnanobind-torch_mlir.so` (NOT `libnanobind-mlir.so`).
  - `python -c "import mlir.ir; from torch_mlir import fx"` exits 0 with no PyGlobals assertion.
- [ ] If both pass, proceed to Phase 1. Otherwise, fall back to Path B
  (Phase 0' below).

### Phase 0': Hybrid fallback (Path B) — only if Phase 0 fails

- [ ] Add `tools/build-cuda-runtime.sh` that builds only the
  `mlir_cuda_runtime` target from `third_party/llvm-project` with
  `MLIR_ENABLE_CUDA_CUSPARSE=ON`, against a fresh slim build dir.
- [ ] Update `pyproject.toml` to depend on `mlir-python-bindings` from
  eudsl and `torch-mlir` from llvm/torch-mlir-release wheels (Lighthouse's
  pattern). Remove our `tools/env.sh` PYTHONPATH overrides — the wheels
  win in site-packages.
- [ ] Smoke test: `python -c "from lighthouse.ingress.torch import cpu_backend"` succeeds.

### Phase 1: Wire Lighthouse into our dependency graph (small change)

- [ ] Add `third_party/lighthouse` submodule, pinned to a chosen commit
  (suggest current main: `455d61c BF16 matmul from KernelBench working`).
- [ ] Update `pyproject.toml` to depend on Lighthouse via local file
  install: `lighthouse @ file:///x/workspace/third_party/lighthouse`. Add
  Lighthouse's three indexes (`eudsl`, `pytorch`, `torch_mlir`) to our
  `[tool.uv.sources]` if going Path B. Adopt their `tool.uv.conflicts`
  pattern for our cpu/cuda extras (regardless of path).
- [ ] Smoke test: `python -c "import lighthouse; from lighthouse.pipeline.driver import CompilerDriver"` succeeds.
- [ ] Smoke test: their `examples/ingress/torch/compile_model.py` runs to
  completion under our venv (this validates whichever path we chose).

### Phase 2: Replace `gnnc/harness/` stubs with Lighthouse-backed code

- [ ] Delete `gnnc/harness/ingress.py` and `gnnc/harness/runner.py`.
  Re-export from `gnnc/ingress/__init__.py`:
  ```python
  from lighthouse.ingress.torch import (
      import_from_model, import_from_file, cpu_backend, gpu_backend,
      TargetDialect, MLIRBackend, JITFunction,
  )
  ```
  Same for `gnnc.execution`: re-export from `lighthouse.execution.runner`.
- [ ] Replace `gnnc/harness/recipes.py` Python-registry with a YAML-driven
  pattern. Define `gnnc/recipes/{cpu,cuda}/{gcn,sage,gat}.yaml`. Each
  recipe is composed of Lighthouse's bundled pieces (`bufferization.yaml`,
  `llvm_lowering.yaml`) plus our `gnn-*.py` schedule modules.
- [ ] Keep `gnnc/harness/golden.py` and `compare.py`. They're the part of
  our setup that isn't in Lighthouse (per-model output correctness).
- [ ] Update `gnnc cli.py` to instantiate Lighthouse's `CompilerDriver`
  with our recipe YAMLs, then call `lighthouse.execution.runner.Runner`.

### Phase 3: Add our domain-specific schedules

- [ ] `gnnc/schedule/sparse_message_passing.py` — Python schedule builder
  that emits a transform-dialect module fusing
  `SDDMM → segment-softmax → SpMM` for the GAT pipeline. Modeled on
  `lighthouse/schedule/x86/tile_and_vector_matmul.py`.
- [ ] `gnnc/schedule/gcn.py`, `sage.py`, `gat.py` — model-specific schedule
  builders. Each takes `tile_sizes`, `target` ("cpu" | "cuda"), and emits
  the appropriate transform module.
- [ ] `gnnc/ingress/pyg_rewrites.py` — Python-level PyG-pre-import rewrites
  (the things we know we need but Lighthouse can't see, like collapsing
  message-passing into a single named op).

### Phase 4: Lit-based test integration

- [ ] Adopt Lighthouse's `lit.cfg.py` substitutions; add our own under
  `test/gnnc/`. Use `REQUIRES: cuda`, `REQUIRES: torch`, etc. so partial
  installs skip cleanly.
- [ ] Port our smoke pipeline test to use `lh-opt --stage=...` invocations
  rather than rolling our own pass-driver.
- [ ] Add a recipe-correctness test: `python -m gnnc run --model=gcn
  --dataset=cora --recipe=cpu/gcn` against a golden output.

### Phase 5: Upstream contributions

- [ ] File HIGH-1 (CUDA runtime in wheels) as an issue at llvm/eudsl.
- [ ] File HIGH-2 (dynamic shape handling in `MLIRBackend`) as a discussion
  at llvm/lighthouse.
- [ ] File MEDIUM-4 (`schedule:`/`transform:` synonymy) as a docs issue at
  llvm/lighthouse.
- [ ] After v0 lands: open an RFC to contribute a sparse-tensor + GPU
  reference recipe upstream. This is the core "feedback to the project"
  the user is hoping for. We'd contribute under the umbrella of
  "downstream recipe upstreamed once it's stable."

### Phase 6 (future): The dialect split

The moment we introduce a `gnn.*` dialect (per `project-summary.md` §13),
we're outside Lighthouse's no-load-bearing-code rule. At that point:

- `gnnc` becomes a *satellite* of llvm-project (IREE-style), consuming
  Lighthouse for harness/ingress/execution only.
- Our dialect, lowerings, and verifiers live in `third_party/llvm-project`
  patches or a `gnn-dialect/` subproject that builds out-of-tree against
  `llvm-project`.
- Lighthouse's recipe model stays useful: we just add `gnnc-opt` to the
  set of binaries available as substitutions in YAML stages.

This is the long-game point where the structural relationship to Lighthouse
matters: by then we'll have validated which Lighthouse APIs we depend on
and can argue (with running code) about what should be upstreamed.

## Worked example: an xegpu MLP schedule (the closest analog to what we'd write)

`lighthouse/schedule/xegpu/mlp_schedule.py` is the most production-grade
schedule in the repo (~540 lines). It's worth dissecting because it shows
what a "real" Lighthouse schedule looks like.

**Structure:**

```python
def mlp_schedule(params: list[dict[str, int | None]],
                 stop_at_stage: str = "") -> ir.Module:
    """Generate transform schedule module for MLP payload."""
    with schedule_boilerplate() as (schedule, named_seq):
        func = match(named_seq.bodyTarget, ops={"func.func"})
        payload_mod = transform.get_parent_op(...)
        # 1. Materialize tunable knobs with SMT constraints
        for layer_params in params:
            layer_params |= params_with_constraints_imposed(...)
        try:
            bundle_xegpu_mlp_schedule(payload_mod, params, stop_at_stage)
        except PipelineInterrupt: pass
        finally:
            transform.yield_()
    return schedule
```

The actual lowering work happens in `bundle_xegpu_mlp_schedule`, which is
a single ~150-line function that does:

1. Match `linalg.matmul` ops, split into per-layer handles.
2. Per layer: wg-tile (workgroup), then k-tile (reduction), then vectorize,
   then hoist loop invariants.
3. Bufferize (one-shot).
4. Convert `scf.forall` → `scf.parallel` → `gpu.launch`.
5. `gpu-kernel-outlining`, set XeVM target with chip "bmg".
6. `convert-vector-to-xegpu`.
7. Per-layer XeGPU annotation: prefetch insertion, anchor-layout for DPAS,
   LICM, cleanup.

A `stop_at_stage` parameter lets the caller stop the lowering early (e.g.
"give me the bufferized form for debugging"). Useful pattern; **we should
adopt it**.

**Tunable knobs woven through:** every numerical parameter
(`wg_m`, `sg_m`, `k_tile`, prefetch tile sizes, etc.) is either a concrete
int or a `KnobValue` via `knob("wg_m")`. SMT-style constraints
(`smt_ext.assert_(WG_M % SG_M == 0)`) are added inline.
`td_smt_ext.constrain_params` decorator wraps a Python function so that
calling it with `KnobValue`s emits SMT ops, and calling it with concrete
ints just runs the function.

**For our GAT pipeline:** the analog is

```python
def gat_schedule(num_layers, target="cuda", **knobs) -> ir.Module:
    with schedule_boilerplate() as (schedule, named_seq):
        func = match(named_seq.bodyTarget, ops={"func.func"})
        payload_mod = transform.get_parent_op(...)
        try:
            # 1. Match the message-passing pipeline (SDDMM → softmax → SpMM-w-msg)
            # 2. Annotate sparse encoding on edge_index tensor
            # 3. Apply sparsification-and-bufferization
            # 4. Tile by node block (parallel iter)
            # 5. Convert to gpu.launch for CUDA target
            # 6. Apply sparse-gpu-codegen → cuSPARSE wrappers
            # 7. gpu-kernel-outlining, nvvm-attach-target
            ...
        except PipelineInterrupt: pass
        finally:
            transform.yield_()
    return schedule
```

Roughly the same shape; what's different is *which* MLIR transform ops we
call. The `bundle_*` factoring keeps each stage independently testable.

**FEEDBACK** (low priority): the `stop_at_stage` parameter is implemented
by throwing a `PipelineInterrupt` exception caught by the outer function.
Works, but feels hacky. A cleaner pattern would be staged pipelines composed
of explicit stage objects (a la `lighthouse.pipeline.stage`) that can be
sliced by index. Worth a design discussion.

## The canonical integration template (from `examples/xegpu/torch_matmul.py`)

This file is the single best end-to-end demonstration of consuming
Lighthouse via the `gpu_backend(fn_compile)` path. It's worth quoting
because it's exactly the structural template our `gnnc run` should follow.

The key 30 lines:

```python
from mlir import ir
from mlir.dialects import transform
from mlir.dialects.transform import structured
from lighthouse import dialects as lh_dialects
from lighthouse import schedule as lh_schedule
from lighthouse.pipeline.driver import TransformDriver
from lighthouse.utils.mlir import get_mlir_library_path
from lighthouse.schedule.xegpu import mlp_schedule, xegpu_to_binary
from lighthouse.ingress.torch import gpu_backend, TargetDialect


def schedule_modules(parameters) -> list[ir.Module]:
    schedules = []

    # Boilerplate: mark the entry func for C-callable emission
    with lh_schedule.schedule_boilerplate() as (sched, named_seq):
        func_op = structured.MatchOp.match_op_names(named_seq.bodyTarget, ["func.func"])
        transform.apply_registered_pass(transform.any_op_t(), func_op, "llvm-request-c-wrappers")
        transform.yield_()
    schedules.append(sched)

    # The actual lowering schedule (target-specific Python module)
    schedules.append(mlp_schedule(params=[parameters]))

    # Final lowering to binary
    schedules.append(xegpu_to_binary())

    return schedules


def lower_to_llvm(module, parameters):
    pipeline = TransformDriver(schedule_modules(parameters))
    return pipeline.apply(module)


# Then in main:
with ir.Context() as ctx, ir.Location.unknown():
    lh_dialects.register_and_load()
    fn_compile = partial(lower_to_llvm, parameters=params)
    model.compile(
        dynamic=False,
        backend=gpu_backend(
            fn_compile,
            device=xpu_device,
            dialect=TargetDialect.LINALG_ON_TENSORS,
            ir_context=ctx,
            shared_libs=shared_libs(),  # ["libmlir_levelzero_runtime.so"]
        ),
    )
    out = model(a, b)  # JIT triggers here
```

**For `gnnc`, the analog is:**

```python
from lighthouse import dialects as lh_dialects
from lighthouse import schedule as lh_schedule
from lighthouse.pipeline.driver import TransformDriver
from lighthouse.ingress.torch import gpu_backend, TargetDialect

from gnnc.schedule import gat_schedule, sparse_gnn_to_binary

def schedule_modules(model_kind, params):
    schedules = []
    # Boilerplate: mark for C-callable emission, sparsity annotation seam
    ...
    # The actual lowering schedule (our Python module emitting transform IR)
    schedules.append(gat_schedule(params))
    # Final lowering to cuSPARSE-wrapped CUDA module
    schedules.append(sparse_gnn_to_binary(target="cuda"))
    return schedules


def lower_to_llvm(module, parameters):
    pipeline = TransformDriver(schedule_modules("gat", parameters))
    return pipeline.apply(module)


with ir.Context() as ctx, ir.Location.unknown():
    lh_dialects.register_and_load()
    fn_compile = partial(lower_to_llvm, parameters=params)
    model.compile(
        dynamic=False,
        backend=gpu_backend(
            fn_compile,
            device=torch.device("cuda"),
            dialect=TargetDialect.LINALG_ON_TENSORS,
            ir_context=ctx,
            shared_libs=[path_to_libmlir_cuda_runtime_so()],
        ),
    )
    out = model(x, edge_index)
```

The structural parallel is exact. The work we have to do is:

1. Write `gnnc/schedule/gat.py` (and gcn, sage) modeled on
   `lighthouse/schedule/xegpu/mlp_schedule.py`. Each module's
   `create_schedule(params)` returns an `ir.Module` containing a
   transform-dialect schedule.
2. Write `gnnc/schedule/cuda/sparse_to_binary.py` analogous to
   `lighthouse/schedule/xegpu/xegpu_to_binary.py`. Final lowering to
   cuSPARSE-wrapped CUDA.
3. Stage `libmlir_cuda_runtime.so` somewhere `shared_libs=[...]` can
   find it (Path A: from our LLVM build; Path B: from our slim
   side-build).

The schedule/pipeline machinery is **already provided by Lighthouse**.
We don't write `TransformDriver`, `CompilerDriver`, `cpu_backend`,
`gpu_backend`, `MLIRBackend`, `JITFunction`, or any of the execution
glue. We write only the sparse-GNN-specific schedules.

## Path C: lh-opt subprocess (last resort, not recommended)

If both Path A and Path B turn out blocked, the absolute fallback is to
invoke Lighthouse through its CLI tools (`lh-opt`, `lh-run`, `kernel_bench`)
via subprocess, never co-loading their Python machinery with ours. We pipe
text MLIR between processes.

**Pros:**
- Zero in-process collision risk.
- No Python-API coupling.

**Cons:**
- We lose the `torch.compile` Dynamo-backend integration entirely.
  Workflow becomes: import model → write MLIR file → `subprocess.run([
  "lh-run", "--stage=our.yaml", "model.mlir"])`. Awkward for inference,
  hopeless for any kind of iterative use.
- Slow: every invocation pays the cost of process spawn + Python import +
  MLIR context initialization.
- No autotuning hookup (their `lh-tune` would also be a subprocess).

**〔thought〕** Mention for completeness but don't pursue. If Path A and
B both fail, the right move is to escalate by filing the
`MLIR_BINDINGS_PYTHON_NB_DOMAIN` documentation issue upstream and asking
for guidance.

## Lighthouse commit pin candidates

When we add `third_party/lighthouse`, we need to pick a commit to pin. Two
candidates as of 2026-05-15:

| Candidate | Reasoning | Risk |
|---|---|---|
| `455d61c BF16 matmul from KernelBench working (#145)` | Current tip of `main`. Most recent capabilities (BF16 KernelBench works). | Most exposed to in-flight #139 refactor; we may need to chase a rename within weeks. |
| `8a58444 Remove pass bundles in favour of yaml files (#134)` | The "yaml descriptors are the canonical recipe" commit. Before per-kernel KernelBench wiring (#140, #144, #145) that's iterating fast. | Misses recent CPU-pipeline modularization; if we want to use those bundles, we'd need to chase forward. |

**〔thought〕** Start with the tip (`455d61c`); bump deliberately when
#139 lands or when our YAMLs break. The cost of an upgrade is just a
submodule pointer change plus checking that our YAMLs still parse. The
cost of starting too far back is missing capabilities.

## Final synthesis

### Recommendation (revised after collision discovery)

**Adopt Lighthouse via submodule.** Path A is preferred; Path B is the
fallback if A doesn't pan out within ~1 hour of investigation.

### Path A: Stay on source, fix torch-mlir's SONAME (preferred)

**〔thought〕** Cheapest path. Two CMake flags added to our
`tools/build-torch-mlir.sh`. Keep everything else as-is. **High confidence
this works because we discovered the same flags are already used in
torch-mlir's release-wheel build (`setup.py:119`).**

Steps:

1. **(10 minutes)** Add `-DMLIR_BINDINGS_PYTHON_NB_DOMAIN=torch_mlir` and
   `-DMLIR_PYTHON_PACKAGE_PREFIX=torch_mlir` to `tools/build-torch-mlir.sh`.
   Wipe `$TORCH_MLIR_BUILD`. Rebuild torch-mlir. Verify with
   `readelf -d` that `_mlir.cpython.so` now NEEDs `libnanobind-torch_mlir.so`.
   Confirm `python -c "import mlir.ir; from torch_mlir import fx"` succeeds.
2. **(15 min)** Add `third_party/lighthouse` submodule, pin to `455d61c`.
3. **(15 min)** Update `pyproject.toml` to depend on lighthouse via local
   file install: `lighthouse @ file:///x/workspace/third_party/lighthouse`.
   Adopt their `[tool.uv]` conflicts pattern for our cpu/cuda extras.
4. **(rest of week)** Replace `gnnc/harness/` stubs with re-exports of
   `lighthouse.ingress.torch`, `lighthouse.pipeline.driver`, etc.
   Author our first GNN recipe YAML.

### Path B: Hybrid (wheels + side-built CUDA runtime)

**〔thought〕** Use if Path A's CMake override turns out not to work
(some other SONAME also collides; we'd discover this empirically).

Steps:

1. Switch `pyproject.toml` to depend on `mlir-python-bindings` from eudsl
   index and `torch-mlir` from the release index, instead of our
   source-built mlir.
2. Add `tools/build-cuda-runtime.sh` that builds *only*
   `libmlir_cuda_runtime.so` from `third_party/llvm-project` with
   `MLIR_ENABLE_CUDA_CUSPARSE=ON`. Build target: `mlir_cuda_runtime`.
   Takes minutes, not 30+. Run from our `tools/build-llvm.sh` as an
   auxiliary stage (or as a separate script).
3. Stage the built `libmlir_cuda_runtime.so` in a fixed location and pass
   its path to `Runner(shared_libs=[...])` at execution time.
4. Same #2-#4 as Path A.

Cost vs. Path A: gives up control over LLVM commit pin (we follow eudsl's
nightly), but eliminates the full LLVM/torch-mlir source build. Could be
a net win if our CI is constrained on time.

### Common steps for either path

- **Rename `gnnc/harness/` → split** into `gnnc/{ingress,recipes,schedule,
  execution}/` peer subpackages matching Lighthouse's layout. Drop the
  `harness/` directory.

- **Express compiler pipelines as YAML recipes**, not Python callables.
  Compose by `include:`-ing Lighthouse's `bufferization.yaml`,
  `cleanup.yaml`, `llvm_lowering.yaml`. Our Python schedule builders go in
  `gnnc/schedule/*.py`, called from YAML via the `transform:` key (which
  in YAML practice is often spelled `schedule:` — both work).

- **Use Lighthouse's `cpu_backend(fn_compile)` / `gpu_backend(fn_compile)`
  as the Dynamo entry point.** Our `fn_compile` is a small Python function
  that instantiates a `lighthouse.pipeline.driver.CompilerDriver`, adds
  our recipe YAML as a stage, runs the pipeline, and returns the lowered
  `ir.Module`.

- **Defer the `gnn.*` dialect to post-v0.** The no-load-bearing-code rule
  isn't binding on us (we're downstream), but aligning v0 with it keeps
  the door open to upstreaming v0 as a reference recipe.

- **Don't import `lighthouse.transform.*` directly** in load-bearing
  code. Issue #139 will reshuffle that namespace. Wrap behind a thin
  `gnnc.schedule.shim` if we need short-term access. The
  "core infrastructure" subset (`foreach`, `match_op`,
  `schedule_boilerplate`) is safe per #139's text.

### What we should empirically verify before committing to either path

Originally three open questions; #1 and #3 are now resolved by experiment.

1. ~~**Does `-DMLIR_BINDINGS_PYTHON_NB_DOMAIN=torch_mlir` actually disambiguate
   the SONAMEs in our local build?**~~ **〔fact — verified 2026-05-15〕**
   Yes. Scratch rebuild with the flag produced
   `_mlir.cpython.so` → `libnanobind-torch_mlir.so`; co-load of
   `mlir.ir` + `torch_mlir.fx` + `lighthouse.ingress.torch` succeeds;
   end-to-end `torch.compile` matmul through Lighthouse returns a correct
   result. See the §Empirical section for the full transcript. The only
   build-script change needed is the single `-D` flag.

2. **Does the side-build of `libmlir_cuda_runtime.so` alone work?** Test:
   `cmake --build $LLVM_BUILD --target mlir_cuda_runtime`. **〔guess〕**
   Probably yes — it's a single CMake target with well-defined dependencies.
   The risk is whether its build also pulls in much of the rest of MLIR.

3. ~~**Does Lighthouse's `MLIRBackend` actually trigger the PyGlobals
   collision in practice?**~~ **Answered: yes, immediately.** Ran
   `examples/ingress/torch/compile_model.py` (well, an inlined equivalent
   doing `@torch.compile(backend=cpu_backend(lower_to_llvm))` for `matmul`)
   against our source-built setup; the PyGlobals assertion fires at
   module-load time during `from lighthouse.ingress.torch import
   cpu_backend`. The text-crossing optimization in `import_from_model`
   doesn't help because `lighthouse.ingress.torch.importer` does
   `from torch_mlir.fx import OutputType` at module-import time, which is
   enough to trigger `torch_mlir._mlir_libs._mlir` to load. Then when
   we later import `mlir.ir`, the collision fires.

   So we definitely need either Path A's CMake override or Path B's
   wheel switch. Doing nothing isn't viable.

### What we feed back upstream (the "Right Way" half of the request)

In **rough order of value to the project:**

1. **A CUDA-enabled wheel variant** (issue at llvm/eudsl). The biggest
   blocker for NVIDIA + sparse-tensor users; until fixed, that whole
   demographic must reproduce our hybrid setup.
2. **A working sparse-tensor reference recipe** (PR at llvm/lighthouse).
   Even a CPU-only sparse-SpMM → linalg.generic → bufferize → llvm
   recipe is novel — sparse_tensor is conspicuously missing from
   Lighthouse's tested matrix.
3. **Dynamic-shape ingress support** (discussion at llvm/lighthouse).
   Real-world models, not just KernelBench, need this.
4. **Documentation cleanups**: `schedule:`/`transform:` synonymy, the
   dead `workload/runner.py`, the missing `lh-tune` docs, CLI naming
   inconsistency.
5. **Eventually:** a `gpu/cuda/` schedule subdirectory alongside the
   existing `xegpu/`, with a worked NVIDIA SpMM matmul example. This
   establishes precedent for our recipes to follow.

### What we should *not* do

- **Don't depend on `lighthouse.transform.*` directly.** Issue #139 will
  reshuffle that namespace. Wrap it in a thin `gnnc.schedule.compat`
  shim if we need short-term access.
- **Don't replicate Lighthouse's `tune/` machinery in `gnnc`.** Their
  transform.tune+SMT autotuning is sound; if we need autotuning, extend
  their setup rather than build our own.
- **Don't try to upstream the `gnn.*` dialect into Lighthouse.** Per
  their explicit no-load-bearing-code rule. Either it lives upstream in
  llvm-project (the long-term goal) or in a `gnnc` satellite repo.
- **Don't replace `gnnc/harness/golden.py` and `compare.py`.** They are
  GNN-specific correctness machinery. Lighthouse doesn't have an
  equivalent and shouldn't.

### Confidence levels

- **〔fact〕** Everything quoted from reading the actual code, pyproject,
  wheel contents, RFC thread, recent PRs, and open issues is verified.
  The shared-library collision, its root cause, and the fix flag were
  verified by direct experiment (`readelf -d`, Python import test,
  `CMakeCache.txt` inspection, `grep` of upstream `setup.py`).
- **〔hypothesis〕** Recommendations marked "we should do X" depend on
  user priorities; they are reasonable defaults but not corner-solid.
- **〔thought〕** Architectural choices (e.g., "use YAML recipes not
  Python", "go with Path A over B") are best-judgment from observed
  patterns and the empirical evidence.
- **Path A verification: DONE (2026-05-15).** Scratch rebuild with
  `-DMLIR_BINDINGS_PYTHON_NB_DOMAIN=torch_mlir` confirmed the SONAME
  fix, clean co-load, and a correct end-to-end `torch.compile` result.
  Path A is no longer conditional. The remaining work is mechanical
  integration (submodule, re-exports, recipe YAMLs, GNN schedules) plus
  the one-line `tools/build-torch-mlir.sh` change.

## How to use this document

If a future Claude (or new collaborator) is picking this up cold:

1. **Read the TL;DR.** That's the bottom line.
2. **Read the §Empirical: shared-library collision section.** It's the
   load-bearing technical finding; the rest of the doc orbits it.
3. **Read the §Canonical integration template section.** That's the
   structural shape of what we'll build.
4. **Read §Final synthesis** for the actionable plan.
5. The rest is supporting material — reference it as needed.

The *first* concrete experiment (the torch-mlir SONAME rebuild test)
has been run and **passed** — see §Empirical. The next action is the
mechanical integration (submodule + `tools/build-torch-mlir.sh` flag +
`gnnc` re-exports), gated on user authorization.

The user (rdadolf@gmail.com) asked for this research overnight; their
direction was "do as much research as possible" and "make notes in
internal-docs so the research is not lost." That instruction has been
satisfied to my best ability. The research raised one critical new
finding (the SONAME collision) that was not anticipated by the
project-summary; that finding has been documented in detail along with
its fix.

---

*Document complete. Last updated 2026-05-15.*
