# gpu-codegen probe on a GAT-shaped fused loop

**Verdict: GREEN.** gpu-codegen handles the GAT inner structure natively.

The day-zero gpu-sparsifier probe exercised `--sparsifier` over plain SpMM
(sum reduction, 8×8, single feature dim, `posWidth=32`). This probe scales
that up to the four properties the GAT inner loop actually needs:

| Property | Day-0 SpMM | Here |
|---|---|---|
| Reductions | sum only | sum + segmented max + segmented exp-sum |
| Output feature dim | 1 | 32 (= 4 heads × 8) |
| Index width | `posWidth=32, crdWidth=32` | `posWidth=64, crdWidth=64` |
| Node count | 8 | 64 |
| Pipelines | cpu / gpu-libgen / gpu-codegen | cpu / **gpu-codegen** (libgen would violate the "zero cuSPARSE" condition by design) |
| Compare | bit-identical diff | numerical with tolerance |

Reproducible via `python run.py` inside the devcontainer.

Source artifacts: [run.py](run.py), [gat-kernel.mlir](gat-kernel.mlir),
[dumps/](dumps/). Pinned commits at characterization time:
[third_party/README.md](../../third_party/README.md). Hardware: RTX 4070
(sm_89, Ada Lovelace), driver R581.57, CUDA 13.0 toolkit.

---

## The kernel

Three `linalg.generic` blocks over a shared CSR adjacency `α[64,64]`, with a
dense feature matrix `X[64,32]`:

1. **Row-wise max** — `m[i] = max_j α[i,j]` over edges of row i.
2. **Row-wise exp-sum** — `s[i] = Σ_j exp(α[i,j] − m[i])`.
3. **Weighted aggregation** — `Y[i,k] = Σ_j (exp(α[i,j] − m[i]) / s[i]) · X[j,k]`.

Each stage uses `sparse_tensor.reduce` inside the `linalg.generic` body —
see "Choice of primitive" below for why. Three separate generics, not one
fused kernel; that's deliberate (collapsing to one kernel is a later
milestone's job, this probe is about codegen capability).

α is built from a deterministic pattern:
- Structural mask: `(i + j) mod 11 == 0` (≈ 5.8 nonzeros per row).
- Values: `((i + 2j) mod 13 − 6) · 0.3`, giving f32 values in [−1.8, 1.8].
  Coprime moduli (11 for the pattern, 13 for the value) ensure values vary
  within each row, so the max isn't trivially the unique positive value.

The probe deliberately uses small dimensions (`N=64`, `F=32`) — large enough
to exercise the multi-dim feature axis and non-trivial node count, small
enough for fast iteration and ASCII-readable dumps. Once codegen passes here,
realistic widths (`F = 4 heads × 64 = 256`, `N ∈ [thousands]`) become a knob,
not a structural question.

---

## Pass conditions

All three required, as measured by [run.py](run.py) on the lowered gpu-codegen IR:

| Condition | Required | Observed |
|---|---|---|
| `gpu.binary` block (containing the compiled CUBIN+PTX fatbinary) | ≥ 1 | **1** |
| `gpu.launch_func` calls (one per kernel) | ≥ 1 | **3** |
| `nvvm.target` annotation | ≥ 1 | **1** (`sm_89`, `+ptx80`) |
| Distinct embedded kernels | informational | 3 (kernel0/1/2 — one per stage) |
| Forbidden library symbols (`cuSPARSE`, `mgpuSpMM`, `mgpuSDDMM`, `mgpuCreateSparseEnv`, `mgpuCreateCsr`, `mgpuCreateDnTensor`) | 0 | **0** |
| GPU output vs CPU, max abs diff | ≤ `1e-4` | **`1.000e-6`** |
| GPU output vs CPU, max rel diff | ≤ `1e-3` | **`4.212e-6`** |

Numerical agreement is within single-bit f32 of bit-identical (differences
come from reduction-order variation between the CPU loop and the GPU
parallel reduction). 2048 float values compared.

---

## Choice of primitive: `sparse_tensor.reduce` vs bare `linalg.generic`

GAT's softmax normalizes over a node's actual neighbors — over the *edges*
of the graph, not over the dense N×N (i,j) lattice. That's the math the
probe needs to express, and it determines which IR primitive each stage
uses.

`linalg.generic` describes iteration over a dense index space. When one of
its operands is a sparse tensor, the sparsifier's job is to optimize that
iteration into "visit only the stored values" — but **only when doing so
yields the same result as dense iteration would**. That's true for SpMM
(`mulf(α, b)`): a missing α contributes `0·b = 0`, so skipping it is free.
It's not true for the per-edge bodies in GAT — at a missing edge,
`exp(α - m)` would be `exp(-m)`, an actual non-zero number that has no
place in the softmax sum.

`sparse_tensor.reduce` is the right primitive for that case. It says
"reduce only over the stored values with this explicit identity" —
which is exactly the GAT semantics. All three stages use it:

```mlir
^bb0(%a: f32, %m_val: f32, %out: f32):
  %r = sparse_tensor.reduce %a, %out, %zero : f32 {
    ^bb0(%x: f32, %y: f32):
      %diff = arith.subf %x, %m_val : f32
      %ex = math.exp %diff : f32
      %sum = arith.addf %y, %ex : f32
      sparse_tensor.yield %sum : f32
  }
  linalg.yield %r : f32
```

**Implication for the downstream GAT ingress rewrite:** the per-edge
reductions (segmented max for softmax stability, segmented sum for the
softmax denominator, attention-weighted aggregation) all need
`sparse_tensor.reduce`. SpMM-shape pieces (e.g. the `X @ W` linear
projection in the unfused-GAT pipeline) can stay as `linalg.matmul` /
plain `linalg.generic` since they're zero-annihilating in α.

### Aside: an upstream sparsifier defect

In the course of getting the wrong primitive choice (plain `linalg.generic`
with non-zero-annihilating bodies) to fail in a recognizable way, the
sparsifier crashed instead of refusing. The admissibility check at
[Sparsification.cpp:1447](../../third_party/llvm-project/mlir/lib/Dialect/SparseTensor/Transforms/Sparsification.cpp#L1447)
looks only at the yielded op (so `addf` slips through even when the
body upstream of it isn't annihilating). Once accepted, codegen reaches
`LoopEmitter::enterCoIterationOverTensorsAtLvls` and segfaults building
i64 index arithmetic with a null operand. Noted here so the next person
hitting that doesn't burn time wondering whether the kernel is malformed:
it isn't, but the sparsifier accepts an input it shouldn't and crashes
instead of erroring cleanly.

---

## What this probe does NOT establish

- **Performance.** No timing was captured; the goal was capability.
- **Fusion.** Three kernels here, not one. Collapsing the three
  generics into a single fused loop nest is a later milestone's job.
- **Realistic feature widths.** Probe used `F=32`. The downstream work
  runs at `F = 4 heads × 64 = 256` and arxiv-scale node counts. The
  codegen path is established here; absolute widths are a knob.
- **The full GAT computation.** This probe takes α as a pre-computed
  sparse tensor with the attention values already on the edges.
  Computing α from `(Wx_src, Wx_dst)` via an SDDMM-shape generic is the
  ingress-rewrite step; whether that SDDMM-shape compiles to GPU codegen
  is unverified here, but the access pattern is structurally the same
  as stage 1 (parallel-over-i, reduction-over-j over a sparse α) so it
  should follow the same rules.
