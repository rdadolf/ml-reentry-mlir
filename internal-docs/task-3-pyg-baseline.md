# Task 3: PyG baseline numbers

This is the reference document for "what 'beat PyG' is being measured against."
Re-measure and update if any line under "Environment fingerprint" changes.

**Measurement date:** 2026-05-14 (initial, native fallback only).
**Re-measured:** 2026-05-14 (after torch nightly + cu130 switch + PyG-lib
source-builds; final canonical numbers below).

---

## Environment fingerprint

| | |
|---|---|
| GPU | NVIDIA GeForce RTX 4070 (sm_89, Ada Lovelace) |
| Driver | R581.57 (Windows host, exposed via WSL2) |
| CUDA toolkit (PyTorch's build) | 13.0 |
| CUDA toolkit (devcontainer) | 13.0 |
| Python | 3.12.3 |
| PyTorch | 2.13.0.dev20260514+cu130 |
| triton | 3.7.0+git88b227e2 (pytorch nightly fork) |
| torch-geometric | 2.7.0 |
| ogb | 1.3.6 |
| pyg-lib | 0.7.0 (source-built from master HEAD `0a716712`) |
| torch-scatter | 2.1.2 (source-built from master HEAD `edeb0422`) |
| torch-sparse | 0.6.18 (source-built from master HEAD `2be752eb`) |

Raw JSON:
- [results-nolibs.json](../experiments/day-zero/task-3-pyg-baseline/results-nolibs.json)
  — canonical eager (native PyTorch dispatch).
- [results-nolibs-compile.json](../experiments/day-zero/task-3-pyg-baseline/results-nolibs-compile.json)
  — canonical compiled (`torch.compile(model)`, native dispatch).
- [results.json](../experiments/day-zero/task-3-pyg-baseline/results.json)
  — legacy-compat check (libs installed, eager).

## Canonical numbers

FP32, single forward pass over the full ogbn-arxiv graph (169,343 nodes,
1,166,243 edges, 128 input features, 40 output classes). 100 timed
iterations after warmup. Latency measured with `torch.cuda.Event`; peak
memory captured *after* warmup. **Canonical configuration is libs-masked**
— see "Strategic context" below for why.

Two rows per model: **eager** (`model(x, edge_index)`, 20-iter warmup) and
**compiled** (`torch.compile(model)`, 50-iter warmup to absorb Dynamo +
Inductor first-call overhead).

| Model | Mode | Params | Median (ms) | p90 (ms) | Peak alloc (MiB) |
|---|---|---|---|---|---|
| GCN  | eager    | 10,856 | 10.80 | 11.50 |   896 |
| GCN  | compiled | 10,856 |  5.30 |  5.55 |   295 |
| SAGE | eager    | 21,608 | 15.55 | 16.02 |   871 |
| SAGE | compiled | 21,608 |  7.12 |  7.74 |   302 |
| GAT  | eager    | 43,896 | 34.37 | 35.12 | 3,121 |
| GAT  | compiled | 43,896 | 14.61 | 15.25 |   848 |

Compile speedup is 2.0–2.35× across the three; peak memory drops 65–73%.
GAT benefits most on both axes — Inductor's intra-phase fusion (see
"Inductor verification" below) lands hardest on the per-edge-attention
work GAT does the most of.

Models defined in [examples/models/](../examples/models/) — same definitions
that produced the goldens in `/x/data/goldens/`.

## Two surprising findings worth flagging

### (1) PyG-lib dispatch makes no difference here

Running the same benchmark with `--disable-libs` (which masks
`torch_scatter`, `torch_sparse`, and `pyg_lib` from import so PyG falls back
to its native PyTorch `Tensor.scatter_add_` / `Tensor.scatter_reduce_`
implementations) produces essentially identical numbers:

| Model | libs enabled | libs masked | Δ |
|---|---|---|---|
| GCN  | 10.75 ms | 10.80 ms | +0.5% |
| SAGE | 15.69 ms | 15.55 ms | -0.9% |
| GAT  | 34.75 ms | 34.38 ms | -1.1% |

Within run-to-run jitter. The deltas don't have a consistent sign.

This contradicts the project-doc's implicit assumption that the
`pip install pytorch-geometric` deployment baseline (with the optional
extension wheels) is meaningfully faster than the fallback path. On
**this** hardware + **this** torch version, it isn't.

Most likely explanation: PyTorch 2.13's native `scatter_add_` /
`scatter_reduce_` CUDA kernels are now competitive with `torch_scatter`'s
hand-written kernels on the workload shapes ogbn-arxiv produces. The
extension wheels were a much bigger win in the torch 1.x / early 2.x era;
the gap has narrowed.

Implication for "beat PyG": the bar is **one number**, not two. Either path
through PyG dispatches to ~equivalent kernels and gets ~the same wall time.
Our generated code just needs to beat *that* number.

### (2) torch 2.13.dev/cu130 is ~10–15% slower than torch 2.12.0/cu126

Comparing the canonical numbers above against the earlier measurement done
on torch 2.12.0+cu126 (libs disabled, otherwise identical setup):

| Model | torch 2.12+cu126 | torch 2.13.dev+cu130 | Δ |
|---|---|---|---|
| GCN  |  9.65 ms | 10.80 ms | +12% |
| SAGE | 13.69 ms | 15.55 ms | +14% |
| GAT  | 31.05 ms | 34.38 ms | +11% |

(Both libs-disabled, so the comparison is fair on the dispatch axis.)

Possible causes, not investigated:
- CUDA 13 driver/runtime has higher launch overhead than CUDA 12.6
- torch nightly carries optimization regressions not yet caught
- Some change in `libcusparse` / `libcublas` / `libcudnn` between cu126 and
  cu130 that affects these specific kernels

We accept the new numbers as the baseline. Re-investigating would only
matter if we ever decided to pin a stable torch for performance reasons,
which conflicts with our project goals (CU13 features, Tile IR access).

## Dispatch path detection

In PyG 2.7's `torch_geometric/utils/_scatter.py`, with all three
`WITH_TORCH_SCATTER` / `WITH_TORCH_SPARSE` / `WITH_PYG_LIB` flags set, the
scatter dispatcher prefers `torch_scatter.scatter` for `min`/`max`/`mul`
reductions and falls back to native `scatter_add_` for `sum`/`mean`. GCN
and SAGE both use sum aggregation (so they get native PyTorch); GAT uses
softmax aggregation which dispatches through `torch_geometric.utils.softmax`
(which itself uses `scatter_max` and `scatter_sum`).

So even with all three libraries installed, GCN and SAGE forward passes
actually route through PyTorch's native scatter for the hot path. That's
the structural reason the libs-enabled vs libs-masked numbers above are
identical — they're running the same CUDA kernels either way.

## Strategic context (PyG ecosystem direction)

This baseline is a moving target. Where it's moving — to recap, with
enough breadcrumbs that everything's reconstructable later:

- **`torch_scatter` and `torch_sparse` are effectively deprecated.** Last
  release Oct 2023 (`2.1.2` / `0.6.18`). PyG's installation docs now describe
  them as "optional." `_scatter.py` no longer even checks `WITH_TORCH_SCATTER`
  for sum/mean. They will keep working for years, but no new perf is coming.
- **`pyg-lib` is the surviving extension**, but its scope is *graph-specific*
  ops (sampling, hashmaps, `segment_matmul`, spline). Scatter and SpMM are
  being pushed *upstream into PyTorch itself*. See [PyG Discussion #6109]
  (https://github.com/pyg-team/pytorch_geometric/discussions/6109) for the
  maintainers' framing.
- **`EdgeIndex` is replacing `SparseTensor`** as PyG's canonical graph
  representation. The 2.5/2.6 release notes commit to this explicitly; the
  long-tail migration is tracked in
  [#5867](https://github.com/pyg-team/pytorch_geometric/issues/5867).
- **PyG's stated performance future is `torch.compile`/Inductor**, not new
  hand-written kernels. See the CPU/compile roadmap in
  [#7057](https://github.com/pyg-team/pytorch_geometric/issues/7057).
- **PyG is *not* building fused GAT.** `FusedGATConv` exists only as a
  thin wrapper around third-party `dgNN`, marked `# pragma: no cover` —
  not a maintained PyG path. 2.7 dropped TorchScript on `GATConv` for
  correctness reasons. The aggr roadmap
  ([#4712](https://github.com/pyg-team/pytorch_geometric/issues/4712))
  defers kernel fusion to "future, separate issue not yet opened."

Implications for the project baseline:

1. The thing to beat is **PyG over native PyTorch + `torch.compile`**.
   Inductor already buys ~2× per the numbers above; that's the real bar
   the compiler has to clear. Eager-mode numbers are the floor; compiled
   is the moving baseline. `torch_scatter` is no longer load-bearing.
2. **GAT-class fused attention-aggregation** is structurally not on PyG's
   roadmap — that's the project's wedge. The credibility comparison for
   GAT performance is dgNN
   ([Zhang et al., MLSys 2022](https://github.com/dgSPARSE/dgNN)) and the
   newer **DF-GNN** ([arXiv 2411.16127](https://arxiv.org/html/2411.16127),
   "AT-GNN dynamic kernel fusion"). Reaching ~0.3–0.5× of these is the
   project's stated yellow outcome; matching or beating them is the
   thesis-test.

### Inductor verification (one-off)

Settled the open question of how much Inductor closes the gap against
fused GAT by tracing a single `GATConv.forward` through `torch.compile`
and counting kernels:

- **9 distinct Triton kernels, 3 compile units (2 graph breaks), 1
  extern cuBLAS matmul.** Same result with libs enabled and libs masked
  — Inductor sees the same shape either way.
- Inductor *does* fuse aggressively within each phase (e.g., the
  segment-softmax-denominator scatter-add absorbs the surrounding
  `exp`/`sub`/`index_select` work into one Triton kernel). More capable
  than the "Inductor can't fuse scatter" caricature.
- But Inductor does *not* fuse across the segment-softmax → aggregation
  boundary; it cannot express the dgNN/DF-GNN pattern of materializing
  the normalizer in shared memory and consuming it locally. That cross-
  irregular-iteration fusion is what an MLIR-based GNN compiler
  unlocks.

Reproducible:
[experiments/day-zero/task-3b-inductor-fusion/run.py](../experiments/day-zero/task-3b-inductor-fusion/run.py).
Generated Triton code dumps in `dumps/`.

### Where Inductor lags dgNN/DF-GNN

dgNN's published GAT-forward times on similar workloads are in the
sub-5ms range vs our 14.6ms compiled — roughly a 3× gap that the project
intends to close. The gap is a stack of three issues, in decreasing
order of impact:

**1. Cross-stage fusion (dominant).** Inductor's 9-kernel layout means
9 launches with global-memory round-trips between them. dgNN fuses to
1 kernel that holds the softmax normalizer and gathered messages in
shared memory / registers throughout. Back-of-envelope for our GAT on
ogbn-arxiv (1.17M edges × 4 heads × 64 hidden, RTX 4070 effective ~500
GB/s):

- Gathered-messages tensor: `1.17M × 4 × 64 × 4B ≈ 1.2 GiB`
- Attention-logit tensor: `1.17M × 4 × 4B ≈ 19 MiB`
- Each kernel boundary that writes-then-reads the gathered-messages
  tensor costs ~4–5ms of DRAM time alone.

Even being conservative about which boundaries actually re-read the big
tensor, this accounts for the bulk of the 14.6ms → ~5ms gap. Pipeline-
level fusion across irregular iteration is what the MLIR sparse-tensor
dialect is designed to enable; this is the project's primary wedge.

**2. Thread/memory mapping for irregular workloads.** dgNN does
degree-bucketing — edge-parallel for high-degree nodes, node-parallel
for low-degree — so warps don't sit idle on the long tail of power-law
graphs. Triton-generated kernels pick one parallelization strategy per
kernel and live with the load imbalance. Significant on power-law
distributions like ogbn-arxiv; less so on uniform graphs.

**3. Template specialization.** dgNN has hand-tuned templates for
common attention head counts (4/8/16) with specific register tiling
and warp-shuffle choices. Triton autotunes tile sizes within a bounded
search budget; it doesn't search the full design space (warp shuffles
vs shared memory, register tiling variants). Probably 10–20% on top of
(1) and (2).

DF-GNN's contribution over dgNN is mostly in (2) — runtime dispatch to
fusion templates based on graph statistics — plus backward-pass fusion
that dgNN doesn't cover.

**Project implications.** 〔hypothesis〕 Closing (1) captures the bulk of
the gap and is the v0/v1 target. (2) is a v2/v3 problem requiring
compile-time reasoning about graph statistics. (3) is what hand-tuned
baselines always win on; "10–20% off dgNN on head specialization" is a
fine outcome to report. No dgNN measurements on this hardware yet —
the arithmetic is grounded in dgNN's published numbers and RTX 4070
bandwidth, not a local A/B.

## Notable caveats

- **Single-graph, single-forward.** No batching, no training loop, no
  backward, no data movement, no model init. Just the kernel work.
- **WSL2 latency floor.** Single-digit microseconds of GPU-launch overhead
  per kernel, mostly invisible at ms-scale forwards but flag-worthy if we
  ever chase sub-ms latency.
- **Memory numbers track torch's CachingAllocator**, not actual VRAM
  utilization. The kernel working-set is smaller than `peak_allocated`
  suggests, but the allocator number is what budgets against
  `nvidia-smi`-reported usage.
- **`short-term-tasks.md` stipulated "no Inductor, no compile".** That
  stipulation reflects a 2022-era framing where torch.compile for PyG was
  experimental. In 2026 PyG explicitly bets on Inductor as its performance
  future, so the doc now reports both eager and compiled rows. Compile-time
  is absorbed by warmup (50 iters for compiled, 20 for eager) and excluded
  from per-iter timing.
- **PyG libs source-built, not wheel-installed.** PyG's wheel index
  (`https://data.pyg.org/whl/`) doesn't yet publish torch-2.13 wheels.
  Building from master pins is the path to having these in the same venv
  as our compiler — see [third_party/README.md](../third_party/README.md)
  and [tools/build-pyg-libs.sh](../tools/build-pyg-libs.sh).

## Reproducing

```bash
source tools/env.sh
# canonical eager (libs masked, PyG dispatches through native PyTorch):
python experiments/day-zero/task-3-pyg-baseline/run.py --disable-libs
# canonical compiled (torch.compile on top, same dispatch):
python experiments/day-zero/task-3-pyg-baseline/run.py --disable-libs --compile
# legacy-compat check (libs installed, eager — mostly the same kernels):
python experiments/day-zero/task-3-pyg-baseline/run.py
```

`--n-warmup` (default 20 eager / 50 compiled) and `--n-timed` (default 100)
are overridable.
