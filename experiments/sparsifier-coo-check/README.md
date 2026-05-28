# MLIR sparse_tensor: COO vs CSR maturity check

**Assessment: GREEN for CPU, YELLOW for direct GPU codegen.**

For every common sparse-tensor operation pattern we tested (SpMM, in-place
elementwise, sparse+sparse binary, segmented reduction, weighted SpMM),
the MLIR `sparse_tensor` dialect produces **bit-identical numerical
results** between `{Compressed-Nonunique, Singleton}` (COO) and
`{Dense, Compressed}` (CSR) encodings on the CPU sparsifier path. For
GPU code generation, COO does not directly trigger the codegen rewriter
(it requires a dense outer dim), but an in-MLIR `sparse_tensor.convert`
from COO to CSR is essentially free and unlocks the full CSR GPU
codegen path. The `EdgeIndex`-style "store as COO, materialize CSR on
demand" pattern maps cleanly to this.

Source artifacts: [run.sh](run.sh), the `0N-*-{csr,coo}.mlir` files,
and per-test dumps in [dumps/](dumps/). Pinned commits at
characterization time:
[third_party/README.md](../../third_party/README.md). Hardware: RTX 4070
(sm_89, Ada Lovelace), driver R581.57, CUDA 13.0 toolkit; LLVM 23.0.0git
built per `tools/build-llvm.sh`.

## Question

Two questions, motivated by the COO-vs-CSR discussion in the project's
[sparse-tensor format research](../../internal-docs/lighthouse-integration-research.md)
and the `EdgeIndex` writeup in
[experiments/pyg-baseline](../pyg-baseline/README.md):

1. **CPU parity**: does MLIR's `sparse_tensor` sparsifier handle COO
   encodings as cleanly as CSR for the operation patterns gnnc cares
   about (SpMM, SDDMM-shape, segmented reduction, weighted aggregation)?
2. **GPU codegen**: does the direct GPU codegen path
   (`SparseGPUCodegen.cpp`'s rewriter) accept COO encodings, or is the
   path effectively CSR-only?

Answer for the first: yes, with one caveat (see "Pattern that
doesn't lower" below). Answer for the second: not directly, but the
in-MLIR convert path is the safety valve.

## Operation patterns tested

| Test | Operation | CSR | COO | CSR vs COO |
|---|---|---|---|---|
| 1 | SpMM (sparse × dense → dense, 8×8 @ 8×8) | ✅ | ✅ | bit-identical |
| 2 | Sparse-in-place scale (`outs(%sparse)` only) | ✅ | ✅ | values identical |
| 3 | Sparse + sparse → sparse binary add (merge over union) | ✅ | ✅ | values identical (34 nonzeros) |
| 4 | Per-row sum reduction (sparse → dense, "matvec-with-ones" idiom) | ✅ | ✅ | bit-identical |
| 5 | Weighted SpMM, non-square dense (8×8 @ 8×4 → 8×4) | ✅ | ✅ | bit-identical |
| 6 | GPU codegen on COO directly | n/a | ❌ | 0 GPU ops emitted |
| 7 | GPU codegen via `sparse_tensor.convert` COO → CSR | n/a | ✅ | 47 GPU ops, output matches Test 1 |

"Values identical" (Tests 2, 3) means the `nse` count and `values:`
array printed by `sparse_tensor.print` match exactly between the two
formats. The `pos[]`/`crd[]` arrays differ — they describe the storage
layout, and that's expected to differ between encodings.

## What's in the COO encoding

```mlir
#COO = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d0 : compressed(nonunique), d1 : singleton),
  posWidth = 32, crdWidth = 32
}>
```

`compressed(nonunique)` on the outer dim permits duplicate row
coordinates — the multigraph-style semantics PyG's `EdgeIndex` has by
default (no requirement that `(i, j)` pairs be unique).

## Tests 1–5: CPU sparsifier parity

For every test, the structure is identical between the CSR and COO
variants except for the `#sparse_tensor.encoding` attribute. The
`--sparsifier="enable-runtime-library=true"` pipeline accepts both,
emits format-specific loop nests over `pos`/`crd` arrays, and produces
numerically-identical results.

Concrete confirmation per test (from [dumps/](dumps/)):

- **Test 1 (SpMM)**: both formats produce the same 8×8 dense matrix:
  row 0 = `[3.6, 3.69, 3.78, 3.87, 3.96, 4.05, 4.14, 4.23]`, etc.
- **Test 2 (scale)**: both produce `nse = 20`, `values: (6, 12, 6, 12, 6, 12, 18, ...)`.
- **Test 3 (binary add)**: both produce `nse = 34`, identical 34-element values array.
- **Test 4 (segreduce)**: both produce `[9, 9, 18, 18, 15, 27, 27, 21]`.
- **Test 5 (weighted SpMM)**: both produce the same 8×4 matrix:
  row 0 = `[225, 229.5, 234, 238.5]`, etc.

The CPU sparsifier's level-format generality is real: any combination
of `dense`/`compressed`/`compressed(nonunique)`/`singleton` produces
working code, with the per-level access pattern dispatched on the
format flag. This matches the Chou-Kjolstad format-abstraction theory
the dialect is built on.

## Test 6: direct GPU codegen does NOT fire on COO

Running `--sparsifier="enable-runtime-library=false
parallelization-strategy=dense-outer-loop ..."` on
[01-spmm-coo.mlir](01-spmm-coo.mlir): the lowered output contains
**zero** `gpu.binary` / `llvm.call @mgpu*` ops. The compute still
executes correctly — it falls through to host code, not the runtime
library — but no GPU kernel is emitted. Same outcome with
`parallelization-strategy=any-storage-outer-loop`.

The mechanism: `SparseGPUCodegen.cpp`'s `ForallRewriter` matches
`scf.parallel` ops emitted by `parallelization-strategy=dense-outer-loop`.
That strategy only fires on a dense outer dim — CSR's `(dense,
compressed)` qualifies, COO's `(compressed(nonunique), singleton)` does
not. No `scf.parallel`, no rewrite trigger, no GPU module.

**Verified the GPU codegen rewriter itself still works in our pinned
LLVM**: re-ran the original [experiments/gpu-sparsifier](../gpu-sparsifier/)
CSR test through the same pipeline → 47 GPU ops emitted. Not a build
regression; specifically a COO storage limitation.

## Test 7: the safety valve — in-MLIR COO → CSR convert

The trivial workaround: declare the input as COO at the boundary, then
emit a `sparse_tensor.convert` to CSR inside the function before the
matmul:

```mlir
func.func @spmm_from_coo(%A_coo: tensor<8x8xf32, #COO>,
                         %B: tensor<8x8xf32>,
                         %C: tensor<8x8xf32>) -> tensor<8x8xf32> {
  %A_csr = sparse_tensor.convert %A_coo
    : tensor<8x8xf32, #COO> to tensor<8x8xf32, #CSR>
  %D = linalg.matmul ins(%A_csr, %B : ...) outs(%C : ...) -> ...
  return %D : ...
}
```

Result: 47 GPU ops emitted (identical to the CSR-only control), and the
output is **bit-identical to Test 1's CSR baseline** when run on GPU.
The convert is a single op that the sparsifier inlines into a
format-conversion pass; downstream code generation is unchanged from
pure CSR.

This is structurally what PyG's `EdgeIndex` does at the Python level:
store COO (`[2, E]`), materialize `rowptr`/`colptr` lazily for CSR
access. The MLIR equivalent — declare input as COO, convert to CSR for
codegen-friendly stages — composes cleanly.

## Pattern that doesn't lower cleanly (not COO-specific)

While building these tests, I hit a sparsifier limitation that's
**independent of the format choice** and worth documenting for future
reference: a `linalg.generic` with a sparse output and *dense
broadcast inputs* (different indexing map than the output) fails to
legalize cleanly in our pinned LLVM, regardless of CSR or COO encoding.

Concretely, this *does not* lower:

```mlir
%result = linalg.generic {
  indexing_maps = [
    affine_map<(i,j) -> (i)>,    // xs (broadcast over j)
    affine_map<(i,j) -> (j)>,    // xd (broadcast over i)
    affine_map<(i,j) -> (i,j)>   // sparse output
  ],
  iterator_types = ["parallel", "parallel"]
} ins(%xs, %xd : tensor<8xf32>, tensor<8xf32>)
  outs(%init : tensor<8x8xf32, #ANY>) {
  ...
} -> tensor<8x8xf32, #ANY>
```

Error: `failed to legalize unresolved materialization from
tensor<8x8xf32, #...> to !llvm.ptr that remained live after conversion`,
with the function `return` as the existing live user.

An alternative formulation using `tensor.extract` inside the body to
load from outside-scope dense vectors hits a different failure: a
sparsifier-internal assertion in `Merger.h:244`
(`Assertion 'isValidTensorId(t)' failed`) — i.e., the merge-lattice
tensor-id bookkeeping doesn't accommodate body-side tensor reads that
aren't declared as `ins()`.

Both failure modes occur with both CSR and COO — same errors, same
locations — so they aren't differentiators between the formats. They
are real limits on what the current sparsifier accepts.

**Concrete impact for gnnc**: GAT's per-edge attention compute
(SDDMM-shape: `α[i,j] = LeakyReLU(α_src[i] + α_dst[j])` over adjacency
nonzeros) can't be written as a single `linalg.generic` in our pinned
LLVM. Workarounds:

1. Precompute the per-edge value as a fully-dense `[N, N]` tensor (the
   `α_src[i] + α_dst[j]` outer sum is cheap), then use a
   sparse-in/sparse-out elementwise to sample by adjacency. Allocates
   the dense intermediate but is well-supported.
2. Use the upstream `sparse_tensor.binary` op pattern (the one from
   `sparse_binary.mlir`) which gives explicit control over per-element
   semantics with two sparse inputs. Requires the per-edge value
   already exist as a sparse tensor, so still needs step 1.
3. Wait for the sparsifier to grow direct support for dense-broadcast-
   in / sparse-out generics, or upstream the support ourselves.

This is the same limitation noted in
[experiments/gpu-sparsifier/README.md](../gpu-sparsifier/README.md)'s
*"the sparsifier has no rule for sparsifying scatter-with-reduction-body"*
discussion, in a different incarnation. Worth flagging as a real
constraint on what the dialect can express today.

## Implications for gnnc

**Net for gnnc's representation choice:**

| Question | Answer |
|---|---|
| Is COO mature enough for the CPU sparsifier path? | **Yes.** Every CPU op tested produces bit-identical results to CSR. |
| Does COO go through direct GPU codegen? | **No.** The codegen rewriter requires a dense outer dim. |
| Is the COO → CSR conversion an obstacle? | **No.** Single `sparse_tensor.convert` op, downstream codegen is identical to pure CSR. |
| Should gnnc *internally* prefer one format? | For codegen, CSR — direct GPU path support, more mature lowering paths. The COO-at-boundary, CSR-inside design (mirroring `EdgeIndex`'s lazy cache) is the right shape. |
| Should gnnc *accept* COO at ingress? | Reasonable to support both; the conversion cost is one op. The PyG `EdgeIndex` data layout naturally surfaces as COO. |

**The COO maturity concern is largely unfounded for CPU paths.** It is
*real* for direct GPU codegen, but the workaround (in-MLIR conversion
to CSR) is trivial and produces code identical to native-CSR output.
For GPU work, gnnc can:

- Accept COO at the boundary (matches PyG ingestion shape)
- Emit `sparse_tensor.convert` to CSR inside the ingress wrapper
- Let the sparsifier produce GPU code from CSR

This is the same "store COO, materialize CSR on demand" design as
`EdgeIndex` — the equivalence is exact at the MLIR level.

## Synthesis with COMET research

A separately-conducted research thread compared COMET (PNNL's
TACO-derived sparse-tensor compiler in MLIR) against MLIR's
`sparse_tensor` and PyG's `EdgeIndex`. The TL;DR from that thread,
relevant to this experiment:

- **COMET and MLIR `sparse_tensor` are parallel implementations of the
  same Chou-Kjolstad level-format theory.** Same four primitive
  formats (`dense` / `compressed` / `compressed-nonunique` / `singleton`
  in MLIR-speak; `D` / `CU` / `CN` / `S` in COMET-speak), same
  merge-lattice-style codegen.
- **COMET's `ta.spTensor_construct` op surfaces the dense `pos`/`crd`/
  `val` arrays as SSA values before packaging them into the sparse
  type.** MLIR's `sparse_tensor.assemble` does the same job; the
  construction-boundary shape is similar.
- **Neither tool natively accepts a `[2, E]` dense edge_index without
  a packing step.** PyG's `EdgeIndex` looks closer to COMET's
  construction boundary than to MLIR's, but the internal representation
  is the same in spirit.
- **COMET has features useful for GNN that MLIR lacks**: first-class
  `semiring` attribute on multiply ops, first-class `mask` operands,
  and an explicit Index Tree (IT) mid-IR for workspace transformations.

Combined with the empirical findings here: **MLIR `sparse_tensor` is
mature enough for gnnc's v0 needs** (all the CPU paths work, and the
GPU codegen story has a clean workaround for COO inputs). The COMET
techniques worth borrowing — Index Tree as a separable mid-IR,
first-class semiring/mask, workspace transformation — are *additional*
ideas to bring into the gnnc design over time, not reasons to switch
off MLIR's dialect.

## Reproducing

```bash
source tools/env.sh
experiments/sparsifier-coo-check/run.sh
```

Per-test outputs land in `dumps/`. Lowered IR is in `dumps/*.lowered.mlir`.
Final stdout from each `mlir-runner` invocation is in `dumps/*.out.txt`.

## Open follow-ups

- **Confirm SparseGPUCodegen.cpp's specific failure point on COO**: I
  inferred from the absence of `gpu.binary` ops that the rewriter
  doesn't match COO's outer level. A direct check would be to dump the
  IR after each sparsifier pass and observe whether `scf.parallel` is
  emitted on the COO path. Tractable, half-day effort.
- **Try `compressed` (unique) as the outer COO dim instead of
  `compressed(nonunique)`.** PyG's `EdgeIndex` defaults to allowing
  duplicates, but a sort + uniquify pre-step could produce a unique
  outer dim. Whether the GPU codegen accepts that is unverified.
- **Test with realistic-scale sparsity (Cora, OGB-Arxiv)** to confirm
  the CPU parity holds at scale. The toy 8×8 here doesn't exercise the
  parallelization paths heavily; structural correctness is established
  but performance characteristics aren't.
- **Direct SDDMM-shape support**: file or check for an existing
  upstream issue about `linalg.generic` with sparse-out + dense-
  broadcast-in. If the limitation is known, that's useful context for
  scheduling. If it's not, contributing a minimal reproducer would be
  a small upstream contribution.
- **Block formats (BSR / BSC)** for fixed-block sparsity. Relevant for
  GNN inner dimensions (heads × hidden) but not exercised here.
