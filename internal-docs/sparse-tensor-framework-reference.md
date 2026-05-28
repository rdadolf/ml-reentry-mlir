# Sparse tensor patterns across GNN frameworks — reference

A reference for how PyG/Inductor, DGL, dgNN, and SparseTIR represent and
compute on sparse graph data, and how MLIR's `sparse_tensor` dialect
aligns or fails to align with each. Used to ground gnnc design
decisions; this is not aspirational documentation — every load-bearing
claim should be traceable to an experiment, a paper citation, or a
source-code pointer, and tagged with a confidence level.

Confidence tags (used throughout):
- **〔fact〕** verified against a primary source (cited) or by experiment in
  this repo (referenced)
- **〔hypothesis〕** strong inference from indirect evidence
- **〔guess〕** informed speculation, kept here for completeness, needs
  validation
- **〔thought〕** framing or interpretation, not a fact claim

## How to read this document

The "shape" of GNN sparse compute is what frameworks differ on most. To
avoid drowning in framework-specific naming, the doc fixes a single
vocabulary for the operations and then describes each framework's
expression of those same operations.

### The five canonical phases (any message-passing GNN)

| # | Phase | Shape | Inputs | Output |
|---|---|---|---|---|
| **P1** | Per-node linear projection | dense | `X: [N, F_in]`, `W: [F_in, F_out]` | `Wx: [N, F_out]` |
| **P2** | Per-edge value computation | "SDDMM-shape": sparse pattern from adjacency, dense inputs per row/col | adjacency + dense per-node vectors | per-edge tensor `[E, ...]` |
| **P3** | Segmented reduction over edges | sparse → dense per destination | per-edge tensor + dst-of-each-edge | per-node `[N, ...]` |
| **P4** | Per-edge normalize/transform | elementwise on edges using per-node lookups | per-edge tensor + per-dst lookup | per-edge `[E, ...]` |
| **P5** | Weighted aggregation | "SpMM-shape": sparse × dense → dense | sparse adj-with-edge-weights + dense feature matrix | `[N, F_out]` |

- **GCN** uses only P1, P5 (with the sparse matrix being the normalized
  adjacency, no per-edge attention).
- **GAT** uses P1 through P5 (P2 computes attention logits, P3+P4
  implement edge-softmax, P5 aggregates softmax-weighted messages).

P5 (SpMM) is the dominant cost on large graphs. P2 (SDDMM-shape) is the
defining difficulty for attention models — the per-edge value depends on
*both* endpoints' features, with the iteration domain dictated by the
sparse adjacency. P3 is well-understood as segmented `scatter_reduce`.

## Sparse data representations across frameworks

| Framework | Canonical graph representation | Edge values | Format conversions |
|---|---|---|---|
| **PyG (eager) — plain LongTensor** | `edge_index: torch.LongTensor [2, E]` (COO coordinates, separate from values). The original convention, still PyG's default. | Stored separately as `edge_attr: [E, F]` dense tensor | n/a |
| **PyG (eager) — `torch_geometric.EdgeIndex`** | `torch.Tensor` subclass over `[2, E]` LongTensor with cached `rowptr`/`colptr` (PyG 2.5+). MessagePassing detects the type and dispatches to `segment_reduce`/CSR-aware paths via [pyg-team/pytorch_geometric/blob/master/torch_geometric/edge_index.py](https://github.com/pyg-team/pytorch_geometric/blob/master/torch_geometric/edge_index.py) **〔fact〕** | Same — values stored separately | Lazy `fill_cache_()` builds rowptr/colptr |
| **PyG (eager) — `torch.sparse_csr_tensor`** (passed as `adj_t`) | PyG 2.3+ accepts native PyTorch sparse tensors via the `adj_t` argument; goes through `torch.spmm()` which dispatches to cuSPARSE under CUDA **〔fact, [PyG 2.3 release notes](https://github.com/pyg-team/pytorch_geometric/releases/tag/2.3.0)〕** | Bound into the sparse tensor's value array | n/a — passed in already-built |
| **PyG under `torch.compile`** | **Effectively only plain LongTensor is viable.** See "PyG input formats under torch.compile" subsection below — EdgeIndex's caching doesn't survive Inductor compilation (same output as LongTensor + 2 extra runtime aten dispatches); `torch.sparse_csr_tensor` is **incompatible with `torch.compile` entirely** — Dynamo refuses to wrap sparse tensors. **〔fact, verified by probes 2026-05-27〕** | Dense `[E]` tensors flowing through the FX graph | n/a |
| **DGL** | `DGLGraph` object with COO/CSR/CSC created **lazily, on demand** — not concurrently by default. Forward SpMM triggers CSR creation; backward triggers CSC. Sparse format is DGL-internal, not `torch.sparse_*`. **〔fact, [dgl/heterograph.py:6203](https://github.com/dmlc/dgl/blob/master/python/dgl/heterograph.py#L6203)〕** | Stored as graph node/edge data via `g.ndata` / `g.edata`; per-edge values can be passed to message functions | `g.create_formats_()` to eagerly materialize all three; DGL chooses per op |
| **dgNN** | Consumes **CSR + CSC simultaneously** (both pre-built on host side and passed to the fused kernel as rowptr/col_ind + col_ptr/row_ind). **〔fact, [dgNN/operators/fused_gatconv.py](https://github.com/dgSPARSE/dgN/blob/main/dgNN/operators/fused_gatconv.py)〕** | Per-edge values computed inside the fused kernel; intermediates in shared memory per paper §5 **〔fact, [arxiv 2110.09524](https://arxiv.org/abs/2110.09524)〕** | n/a — kernel-internal |
| **SparseTIR** | TVM TensorIR sparse tensor with **composable formats**: same tensor can be horizontally decomposed across multiple formats (e.g., `hyb(c, k)` partitions rows by degree into ELL buckets of size `2^i`). Per-axis attributes: `dense/sparse × fixed/variable`. **〔fact, [arxiv 2207.04606](https://arxiv.org/abs/2207.04606)〕** | Stored as the sparse tensor's value array (per sub-format) | `sparse_fuse` schedule primitive enables sparse-out SDDMM iteration "over non-zero (i,j) directly" **〔fact〕** |
| **MLIR `sparse_tensor`** | `tensor<..., #sparse_tensor.encoding<{map = ..., levels = ...}>>` where levels are `dense`/`compressed`/`compressed(nonunique)`/`singleton`/etc. Either CSR or COO encodes the same logical graph. **〔fact, verified [sparsifier-coo-check](../experiments/sparsifier-coo-check/)〕** | Bound into the sparse tensor as its value array; sparse_tensor.assemble explicitly constructs from `(pos, crd), vals` arrays | `sparse_tensor.convert` between encodings (verified COO ↔ CSR, single op) |

### A subtle point worth pinning

Across all frameworks, the sparse graph structure is *always* present as
data. The question is only whether the **IR carries a sparse-tensor type
annotation** for it, or whether the sparsity is implicit in surrounding
ops (gather, scatter_reduce). PyG today uses the *implicit* form; DGL
the *explicit* form. MLIR `sparse_tensor` is explicit by design.
**〔thought〕** "implicit sparsity" doesn't mean no sparse tensor exists;
it means the IR treats the structure data as dense int64 arrays and
relies on the surrounding ops to give it sparse semantics.

### PyG input formats under `torch.compile` vs `torch.export` — which ingress path do you use?

PyG accepts three graph-structure input formats in eager mode (plain
LongTensor, `EdgeIndex`, `torch.sparse_csr_tensor`). The two PyTorch
tracing paths (`torch.compile` / Dynamo, and `torch.export` /
make_fx-via-fake-mode) treat sparse tensors very differently. **This
distinction is critical for gnnc's ingress design.**

Measured on `torch 2.13.0.dev20260514+cu130`, PyG 2.7.0, RTX 4070:

| Format | `torch.compile(fullgraph=False)` | `torch.compile(fullgraph=True)` | `torch.export` / `make_fx` | `torch_mlir.fx.export_and_import` |
|---|---|---|---|---|
| Plain LongTensor `[2, E]` | **0 breaks** (with `add_self_loops=False`) | ✅ single graph | ✅ produces FX graph | ✅ produces MLIR (no sparse_tensor encoding — graph structure is implicit in int64 ops) |
| `torch_geometric.EdgeIndex` (sorted + cached rowptr/colptr) | **8 breaks** (all "Dynamic shape operator") | ✅ single graph (same Inductor output as LongTensor + 2 extra runtime aten dispatches) | ✅ produces FX graph | (not directly tested, but EdgeIndex is a Tensor subclass — should behave like LongTensor through export) |
| `torch.sparse_csr_tensor` (passed as adj input) | **10 breaks**, including `step_unsupported` | ❌ **Hard failure**: `Unsupported: Attempted to wrap sparse Tensor — torch.compile does not support sparse Tensors` | **✅ FX placeholder has `[layout=torch.sparse_csr, shape=[N, M]]`; `aten._sparse_mm.default` in the graph** | **✅ Produces MLIR with `#sparse_tensor.encoding<{map = (d0,d1) -> (d0:dense, d1:compressed), ...}>` on the input vtensor type** |

**〔fact, verified 2026-05-27〕** Probes: `/tmp/gnnc-probe/probe-pyg-formats.py` (compile kernel counts), `probe-pyg-formats-2.py` (compile break inventory), `probe-aart.py` (compile sparse-input failures), `probe-export.py` (export-path sparse-input successes), `probe-export-pyg.py` (export-path PyG defaults), `probe-export-nonzero.py` (no data-dependent ops in exported PyG graphs). MLIR output for the export path is **verbatim**:

```mlir
#sparse = #sparse_tensor.encoding<{ map = (d0, d1) -> (d0 : dense, d1 : compressed),
                                    posWidth = 64, crdWidth = 64 }>
func.func @main(%arg0: !torch.vtensor<[2,2],f32,#sparse>,
                %arg1: !torch.vtensor<[2,4],f32>) -> !torch.vtensor<[2,4],f32> {
  %0 = torch.operator "torch.aten._sparse_mm"(%arg0, %arg1) : (...)
  return %0
}
```

**〔fact〕** This is exactly what [experiments/fx-sparsity](../experiments/fx-sparsity/)'s b-sparse-mm test established at project start: `torch.sparse_csr_tensor` passed as a model input survives through `torch.export` → torch-mlir → MLIR with `#sparse_tensor.encoding` propagated to the function signature.

**The PR that enabled this**: [pytorch/pytorch#117907](https://github.com/pytorch/pytorch/pull/117907) — "[traced-graph][sparse] propagate sparsity metadata into traced graph", landed May 2024, authored by Aart Bik (also the MLIR `sparse_tensor` dialect author). It extends FakeTensor support to sparse layouts (COO/CSR/CSC/BSR/BSC) and modifies Dynamo variable builders to maintain sparse metadata through tracing. **The Dynamo-variable-builder side does NOT make `torch.compile` accept sparse tensors as inputs** — that remains explicitly refused — but the FakeTensor side makes `torch.export` and `make_fx(tracing_mode="fake")` work. Aart's stated motivation in the PR: useful for "a JIT backend that supports a sparse compiler" — which is gnnc's use case.

### `torch.export` vs `torch.compile` on PyG defaults

Worth a separate cross-check because `torch.export` is also strict (no graph breaks allowed) — does it hit the same `remove_self_loops` / `add_remaining_self_loops` issue that `torch.compile(fullgraph=False)` does on PyG defaults?

**〔fact, verified 2026-05-27 via `probe-export-pyg.py` and `probe-export-nonzero.py`〕** No. `torch.export` traces every PyG configuration tested:

| Config | `torch.compile()` default | `torch.compile(fullgraph=True)` | `torch.export` |
|---|---|---|---|
| GATConv `add_self_loops=True` (PyG default) | 3 breaks | ✅ clean (Dynamo traces through) | ✅ clean (52 call_function nodes, **no data-dependent ops** in graph) |
| GATConv `add_self_loops=False` | 0 breaks | ✅ clean | ✅ clean (39 nodes, no nonzero) |
| GCNConv defaults (`self_loops=True, normalize=True`) | 5 breaks | ✅ clean | ✅ clean (39 nodes, no nonzero) |
| GCNConv `self_loops=False, normalize=False` | 0 breaks | ✅ clean | ✅ clean (9 nodes) |
| SAGEConv defaults | 0 breaks | ✅ clean | ✅ clean (17 nodes) |

The mechanism by which `torch.export` traces through `remove_self_loops` (which uses `aten.nonzero`, a data-dependent op) is via FakeTensor's symbolic-shape inference. The same machinery that lets it carry sparse-tensor metadata also lets it carry through dynamic-output shapes from operations like nonzero **without leaving the data-dependent op in the resulting graph**.

**〔thought〕 `torch.export` is the strictly more capable tracing path for gnnc's use case** — handles every case `torch.compile(fullgraph=True)` handles, plus sparse_csr-tensor inputs.

### Strategic implications for gnnc ingress

**〔risk, load-bearing〕 Lighthouse is migrating its default ingress** from
`import_from_model` (which uses `torch_mlir.fx.export_and_import`, i.e.,
`torch.export`-based) to `MLIRBackend` (`torch.compile`-based). PR
[#157 (a7e5ff5)](https://github.com/llvm/lighthouse/commits/main) on
the Lighthouse side adds the Dynamo plugin mode to `kernel_bench`, with
the commit body noting *"a follow-up PR will add support and enable
this mode by default."* The path we have just established as the only
one that supports `torch.sparse_csr_tensor` inputs is the one Lighthouse
is moving away from. gnnc must plan for either:

1. Maintaining a parallel export-based ingress (bypassing Lighthouse's
   `MLIRBackend` for sparse-tensor-input models)
2. Pushing back upstream to keep both paths supported in Lighthouse
3. Restricting gnnc's accepted input formats to plain LongTensor / EdgeIndex
   (which the Dynamo path does handle), and rejecting `torch.sparse_csr_tensor`
   inputs explicitly

The path matters for the format:

| User writes their PyG model with… | Ingress should use… | gnnc receives FX graph with… |
|---|---|---|
| Plain LongTensor `edge_index` | Either `torch.compile`/Lighthouse `MLIRBackend` or `torch.export` — both work. `fullgraph=True` recommended for the compile path (see [dynamo-graph-breaks](../experiments/dynamo-graph-breaks/)). | Dense `[E]`-shaped gather/scatter ops; no `sparse_tensor` metadata. gnnc constructs sparse-tensor types via `sparse_tensor.assemble` at lowering time. |
| `EdgeIndex` | Either path (functionally equivalent to LongTensor under compile; minor extra runtime dispatch). | Same as plain LongTensor. |
| `torch.sparse_csr_tensor` | **`torch.export` only.** Lighthouse `MLIRBackend` (`torch.compile`-based) **will fail to wrap the input.** | MLIR with `#sparse_tensor.encoding` on the function signature, from `torch_mlir.fx.export_and_import`. |

### Per-layer dispatch on the export + sparse_csr path

**〔fact, verified 2026-05-27 via `/tmp/gnnc-probe/probe-pyg-sparse-export.py`〕** Passing `torch.sparse_csr_tensor` to a PyG conv layer and routing through `torch_mlir.fx.export_and_import` preserves the sparse encoding on the function signature for every layer tested, but the *body* compute differs per layer because PyG's MessagePassing dispatches differently. The MLIR function signatures and body op patterns:

| Layer | MLIR signature | Body op pattern |
|---|---|---|
| **GCNConv** | `%arg1: !torch.vtensor<[N,N],f32,#sparse>` | **`torch.aten._sparse_mm(%arg1, %dense)`** — single sparse matmul on the sparse-typed operand. This is exactly the shape the verified sparsifier SpMM lowering consumes ([sparsifier-coo-check](../experiments/sparsifier-coo-check/) Tests 1, 5, 7). End-to-end ready, no FX rewrite needed for the SpMM step. |
| **SAGEConv** | Same `#sparse` signature | **`torch.aten._sparse_mm(%arg1, %arg0)`** plus auxiliary `torch.aten.crow_indices(%arg1)` extraction for root-features handling. The main aggregation is a clean sparse matmul; the index-extraction is a smaller side path. |
| **GATConv** | Same `#sparse` signature | **`torch.aten.crow_indices(%arg1)` + `torch.aten.col_indices(%arg1)`** extractions, then the same gather/scatter machinery PyG uses for LongTensor input. **No `_sparse_mm` in the body.** The sparse encoding survives on the *type* but PyG's GATConv internally re-decomposes the sparse tensor into its index arrays. |

**What this means concretely:**

- **GCN/SAGE through this path are end-to-end ready** — sparse_csr in, MLIR has `_sparse_mm` + sparse encoding out, sparsifier compiles it. No additional gnnc work required for the SpMM step.
- **GAT requires the planned `pyg_rewrites` to lift `(crow_indices, col_indices) → gather/scatter` back into a sparse-tensor formulation.** The sparse type is preserved at the input boundary (giving the FX rewriter the type information it needs); the body's `crow_indices`/`col_indices` extraction + gather/scatter is the concrete IR pattern to match against. This grounds the long-discussed `pyg_rewrites` task in an actual measured input shape. **〔thought〕** Importantly: this is the *same* pattern PyG emits for LongTensor input, just with the sparse-typed source visible at the head of the chain. The rewrite work doesn't differ structurally between LongTensor and sparse_csr input cases — it's the same FX-pattern target.

**Concrete consequence**: the existing [test/integration/lighthouse_smoke.py](../test/integration/lighthouse_smoke.py) goes through `torch.compile(... backend=cpu_backend(lower))` — that path **cannot** consume models with `torch.sparse_csr_tensor` inputs. For sparse-tensor-input models, gnnc needs a separate ingress that uses `torch.export` (or `torch_mlir.fx.export_and_import` directly). This is two ingress paths, not one. **〔thought〕** The smoke test's matmul model doesn't trigger this; it'll bite the first time someone tries a model that takes a sparse tensor as input.

**For PyG-shape models that use plain LongTensor `edge_index`** (the dominant case in practice), either ingress path works equivalently. The sparse-tensor type is introduced inside gnnc's MLIR pipeline via `sparse_tensor.assemble`, not at the user-facing input boundary. **EdgeIndex's caching is wasted under `torch.compile`** but is harmless via export.

## GCN forward — phase-by-phase across frameworks

**Math.** With normalized adjacency `Ã = D̃^{-1/2}(A + I)D̃^{-1/2}` (or
just `A` after PyG's `GCNNorm` transform), one GCN layer is:

```
X' = σ(Ã · X · W)
```

In the canonical-phase vocabulary above, GCN uses P1 (`X · W`) and P5
(`Ã · (XW)`). There is no P2/P3/P4 — the sparse matrix has no per-edge
computed values; values are just the normalization constants
precomputable from degrees.

### Framework-by-framework

| Phase | PyG (eager) | PyG + Inductor (fullgraph=True) | DGL | dgNN | MLIR sparse_tensor |
|---|---|---|---|---|---|
| P1 (linear) | `aten::mm` → cuBLAS | `aten::mm` → cuBLAS (extern call) **〔fact, [inductor-fusion](../experiments/inductor-fusion/)〕** | `aten::mm` → cuBLAS | **dgNN doesn't ship GCN** — its operators directory has only GAT/GMM/EdgeConv (DGL's g-SpMM is already efficient for non-attention SpMM, nothing to fuse) **〔fact, [dgN/operators/](https://github.com/dgSPARSE/dgNN/tree/main/dgNN/operators)〕** | `linalg.matmul` (dense × dense), standard lowering |
| P5 (SpMM) | **Two paths depending on the input type:**<br>• With LongTensor `edge_index`: gather(X, src) → multiply by per-edge norm → scatter_add(dst) — dense `[E]`-shaped scatter pattern, no sparse type **〔fact, PyG `GCNConv` source〕**<br>• With `torch.sparse_csr_tensor`: dispatches to `torch.spmm()` which dispatches to cuSPARSE in eager **〔fact, PyG 2.3+ docs〕** | Same FX shape (LongTensor path) — Inductor emits Triton kernel(s) for the gather/multiply/scatter; uses cuBLAS extern for the linear; ~7 kernel launches per layer **〔fact, [inductor-fusion](../experiments/inductor-fusion/)〕**. **sparse_csr path is incompatible with `torch.compile`.** | **Single `update_all(copy_u, sum)` call → one g-SpMM kernel.** No per-edge intermediate materialized in global memory; g-SpMM's defining property per DGL paper §3: *"g-SpMM naturally avoids generating intermediate storage for messages"* **〔fact, [dgl/nn/pytorch/conv/graphconv.py](https://github.com/dmlc/dgl/blob/master/python/dgl/nn/pytorch/conv/graphconv.py); [DGL paper](https://arxiv.org/abs/1909.01315)〕** | — (see DGL column) | **Two paths into MLIR:**<br>• Via `torch.compile` on LongTensor input: gather/scatter ops → gnnc would need `pyg_rewrites` + `sparse_tensor.assemble` to lift into the verified `linalg.matmul` sparse path<br>• Via `torch.export` on `torch.sparse_csr_tensor` input: MLIR has `torch.aten._sparse_mm(%arg1 : !torch.vtensor<..., #sparse>, %X)` directly — **end-to-end ready for the verified `linalg.matmul` sparse lowering** **〔fact, probe-pyg-sparse-export.py〕** Fully lowered by sparsifier including GPU codegen **〔fact, [sparsifier-coo-check](../experiments/sparsifier-coo-check/) Tests 1, 5, 7〕** |

### Where GCN's intermediates live

| Framework | Per-edge intermediate (`E × F`)? | Dense `Wx` (`N × F`)? | Notes |
|---|---|---|---|
| PyG eager | Yes — `[E, F]` materialized after gather, before scatter_add | Yes | Two DRAM round-trips: write `gathered_messages[E, F]`, read for scatter |
| PyG + Inductor | Yes, same shape **〔fact, verified by inspecting [inductor-fusion dumps](../experiments/inductor-fusion/dumps/)〕** | Yes | Inductor's intra-kernel fusion can shrink some sub-stages but the gather → scatter boundary remains a kernel boundary |
| DGL | **No** — single g-SpMM kernel, no edge tensor materialized **〔fact, agent-verified against DGL paper §3 and source〕** | Yes | g-SpMM's defining design goal |
| MLIR `sparse_tensor` | **〔hypothesis〕** No — `linalg.matmul` on a sparse operand lowers to a tile-and-iterate loop that holds the per-edge contribution in registers across the multiply+accumulate. Needs sparsifier-emitted-IR inspection to confirm. | Yes | The pattern is direct enough that the sparsifier's CSR lowering should match DGL's g-SpMM shape, but I have not measured this |

## GAT forward — phase-by-phase

**Math (single layer, per head).** Following PyG's formulation:

```
1.  Wx = X · W                              dense [N, F_out]
2a. α_src = a_src · Wx                       dense [N]  — per-source-node scalar
2b. α_dst = a_dst · Wx                       dense [N]  — per-destination-node scalar
2c. e_ij  = LeakyReLU(α_src[i] + α_dst[j])  per-edge, only at (i,j) ∈ E
3a. m_j   = max_i e_ij                       dense [N]  — segmented amax per dst
3b. ẽ_ij  = exp(e_ij − m_j)                 per-edge
3c. z_j   = sum_i ẽ_ij                       dense [N]  — segmented sum per dst
4.  α_ij  = ẽ_ij / z_j                       per-edge (the normalized attention)
5.  out_j = sum_i α_ij · Wx[i]              dense [N, F_out]
```

Phase mapping: P1=(1), P2=(2c) and downstream per-edge stages (3b, 4),
P3=(3a) and (3c), P4=(4) implicit in division, P5=(5).

**The crucial structural fact:** stages 2c, 3b, 4 all have the SDDMM-shape —
output is per-edge with sparsity pattern matching the adjacency, inputs
include dense per-node vectors broadcast over the edge.

### Framework-by-framework

| Phase | PyG eager + Inductor | DGL | dgNN | MLIR `sparse_tensor` |
|---|---|---|---|---|
| (1) Wx | cuBLAS mm | cuBLAS mm | cuBLAS mm | `linalg.matmul` (dense) |
| (2a/2b) α_src, α_dst | Two scatters of `Wx` against attention vectors → dense `[N]` per head | DGL computes them on the dense `feat_src`/`feat_dst` before any graph op: `el = (feat_src * attn_l).sum(-1)` **〔fact〕** | Same precompute outside the kernel; the kernel takes `attn_row`, `attn_col` as ins **〔fact, dgNN signature〕** | `linalg.matmul` / `linalg.generic` (dense) |
| **(2c) e_ij** | LongTensor input: `aten::index_select(α_src, src) + aten::index_select(α_dst, dst) + aten::leaky_relu`. **All on dense `[E]` tensors**, no sparse-tensor type **〔fact〕**<br>**sparse_csr input + export**: same pattern — PyG's GATConv extracts `crow_indices`/`col_indices` from the sparse tensor and runs the same gather/scatter. Sparse encoding present at the function signature but NOT used by the body ops. **〔fact, probe-pyg-sparse-export.py〕** | `graph.apply_edges(fn.u_add_v("el", "er", "e"))` then `leaky_relu(graph.edata.pop("e"))` — **separate kernel from softmax and SpMM**, `e` lives in `graph.edata` between kernels. **〔fact, [dgl/nn/pytorch/conv/gatconv.py](https://github.com/dmlc/dgl/blob/master/python/dgl/nn/pytorch/conv/gatconv.py)〕** | **Fused into one kernel with (3) and (5)**: paper §5 identifies three ops to fuse — Scatter (this), ReduceScatter (softmax), Aggregate (weighted SpMM); intermediates in shared memory **〔fact, [arxiv 2110.09524](https://arxiv.org/abs/2110.09524)〕** | **Open question.** Natural single-`linalg.generic` formulation does not legalize (parallel-only 2-D + dense broadcast ins + sparse out, in our pinned LLVM 23.0.0git). **〔fact, [sparsifier-coo-check Test 2 attempt](../experiments/sparsifier-coo-check/)〕** Two untested workarounds remain (see "Open questions" below). **Side note**: SparseTIR's `sparse_fuse` schedule primitive supports exactly this iteration shape — evidence the pattern is expressible in a sparse-tensor compiler, just not in MLIR's dialect today |
| (3a) m_j | `scatter_reduce` (amax) over `e[E]` indexed by `dst` — dense `[E]` → dense `[N]` **〔fact〕** | Part of DGL's `edge_softmax` operator (a single kernel that does max+sub+exp+sum+div together over the sparse edge tensor). `a = edge_softmax(graph, e)` — `a` materialized to `graph.edata["a"]` between this and (5) **〔fact〕** | Fused; max kept in shared memory per dst block **〔fact, dgNN §5〕** | `linalg.generic` with `parallel/reduction` iteration over a sparse `[N, N]` and dense `[N]` output. **〔fact, verified Test 4〕** Works the same on CSR and COO. |
| (3b) ẽ_ij | `aten::index_select(m, dst) → sub → exp` on dense `[E]` **〔fact〕** | Inside `edge_softmax` (one kernel for all softmax substeps) | Fused | Per-edge elementwise on sparse value array; **〔hypothesis〕** expressible via `sparse_tensor.binary` + `sparse_tensor` elementwise ops on sparse-in/sparse-out generics. Verified primitive works ([Test 3](../experiments/sparsifier-coo-check/)) but exact GAT formulation not tested |
| (3c) z_j | Another `scatter_add` over `ẽ[E]` → dense `[N]` | Inside `edge_softmax` | Fused | Same shape as (3a) — verified Test 4 |
| (4) α_ij | `aten::index_select(z, dst) → div` on dense `[E]` | Inside `edge_softmax` (output is `a` in `graph.edata["a"]`) | Fused | Same shape as (3b) |
| **(5) out_j** | `aten::index_select(Wx, src) → multiply by α → scatter_add(dst)` — gather-multiply-scatter on `[E]` of shape `[E, F]` for the messages **〔fact, [inductor-fusion dump unit2](../experiments/inductor-fusion/dumps/)〕**. Same pattern for both LongTensor and sparse_csr inputs (the body extracts indices either way) | `update_all(fn.u_mul_e("ft", "a", "m"), fn.sum("m", "ft"))` — third kernel call. g-SpMM reads `a` from `graph.edata` (DRAM round-trip), reads `ft = Wx`, produces output. **〔fact〕** | Fused with (2c) and (3) into one kernel launch; α stays in registers, no DRAM round-trip **〔fact〕** | `linalg.matmul ins(%adj_with_alpha_values : tensor<..., #CSR>, %Wx)` — exactly the verified SpMM shape. The only piece needing input prep is `sparse_tensor.assemble` to bind the α `[E]` values to the adj's positions. **〔hypothesis〕** end-to-end expressible; not measured |

### GAT kernel counts (verified)

From [experiments/inductor-fusion/run-followup.py](../experiments/inductor-fusion/run-followup.py),
2026-05-27, RTX 4070, single GATConv layer, libs disabled (PyG falls
back to native scatter), `fullgraph=True`:

- **PyG + Inductor**: 7 Triton kernels + 1 cuBLAS `mm` extern = **8 GPU
  launches per forward**. 2-layer GAT exactly 2× — **zero cross-layer
  fusion**. **〔fact〕**
- **dgNN published**: ~1 kernel for the GAT forward (single fused
  SDDMM+softmax+SpMM). **〔fact, per pyg-baseline citation; needs
  direct paper verification〕**

### GAT under sparse_csr input + export — same shape, different starting point

**〔fact, probe-pyg-sparse-export.py〕** Passing `torch.sparse_csr_tensor`
to GATConv and routing through `torch_mlir.fx.export_and_import` produces
MLIR with sparse encoding **on the function signature** but the body
operations still go through PyG's standard gather/scatter machinery via
`torch.aten.crow_indices(%arg1)` and `torch.aten.col_indices(%arg1)` to
extract the index arrays. The full GATConv decomposition into stages
(1)-(5) above happens identically regardless of input type. **The sparse
input form doesn't shortcut GAT's compute structure** — it just gives
gnnc more type information at the FX boundary.

**Implication for `pyg_rewrites`**: the rewrite pattern that lifts
"index extraction + gather/scatter" back into a sparse-tensor formulation
is the *same shape* whether the input was sparse_csr or LongTensor. The
difference is just whether the sparse type is already on the signature
(sparse_csr input → already there) or has to be constructed via
`sparse_tensor.assemble` from edge_index data (LongTensor input → assemble
needed). Either way, the FX rewrite operates on the same body op
sequence.

## Fusion and intermediate-materialization summary

Where the meaningful (edge-sized) intermediates live in DRAM vs
on-chip per framework:

| Framework | `e[E]` | `ẽ[E]`, internal softmax steps | `α[E]` (normalized) | Weighted messages `[E, F]` | Edge-sized DRAM round-trips |
|---|---|---|---|---|---|
| PyG eager | DRAM | DRAM (each `index_select`/`sub`/`exp` is its own kernel) | DRAM | DRAM | **Many** — one kernel boundary per substage |
| PyG + Inductor `fullgraph=True` | DRAM | DRAM (Inductor fuses *within* each phase but not across scatter-reduce boundaries) **〔fact, [inductor-fusion dumps](../experiments/inductor-fusion/dumps/)〕** | DRAM | DRAM | **Multiple** — observable as the 7-Triton-kernel layout |
| DGL | DRAM (apply_edges kernel ends here) | None (softmax substeps fused in `edge_softmax` kernel) | DRAM (between `edge_softmax` and `update_all`) | None — g-SpMM consumes `α` and `Wx` directly | **2 boundaries** — `e` after kernel 1, `α` after kernel 2 |
| dgNN | None | None | None | None | **0 cycles** — all edge-sized intermediates on-chip; CSR+CSC both consumed by one kernel **〔fact, [arxiv 2110.09524](https://arxiv.org/abs/2110.09524)〕** |
| MLIR `sparse_tensor` v0 (Design A: per-stage `linalg.generic` ops, `[E]`-shaped pre-aggregation) | DRAM | DRAM | DRAM | None (`linalg.matmul` on sparse keeps messages on-chip) **〔hypothesis〕** | **Multiple** — same pattern as PyG+Inductor |
| MLIR `sparse_tensor` + custom fused op (Design C) | None | None | None | None | **0 cycles** — custom MLIR op fuses 2c–5 in one loop nest, reusing sparse_tensor machinery elsewhere |

This is what dgNN's ~3× advantage over PyG+Inductor on ogbn-arxiv is
explained by per the [pyg-baseline writeup](../experiments/pyg-baseline/README.md#L202-L250):
the ~1.2 GiB gathered-messages tensor at scale, with 4× DRAM
round-trips, accounts for the bulk of the ~10ms gap.

## MLIR `sparse_tensor` — what it expresses, what it doesn't (verified)

### Verified working ([sparsifier-coo-check](../experiments/sparsifier-coo-check/))

| Pattern | Status | Test |
|---|---|---|
| `linalg.matmul` on sparse adj × dense (SpMM) | ✅ Both CSR and COO, both CPU and GPU codegen (47 GPU ops emitted) | Test 1, 5, 7 |
| Sparse-in-place elementwise (`outs(%sparse)` only) | ✅ Both formats | Test 2 |
| Sparse + sparse → sparse binary (merge over union) | ✅ Both formats | Test 3 |
| Segmented reduction (sparse → dense per row) via parallel-reduction iteration | ✅ Both formats | Test 4 |
| In-MLIR `sparse_tensor.convert` between encodings (e.g., COO → CSR) | ✅ Single op, downstream codegen unchanged from native CSR | Test 7 |
| GPU codegen via `parallelization-strategy=dense-outer-loop` on CSR | ✅ Produces `gpu.binary` + `llvm.call @mgpu*` | Tests 1, 5, 7; [gpu-sparsifier](../experiments/gpu-sparsifier/) |

### Verified NOT working (in our pinned LLVM 23.0.0git)

| Pattern | Failure mode |
|---|---|
| GPU codegen on `compressed(nonunique), singleton` (COO) directly | Rewriter requires `dense` outer dim — falls through to host code execution (still numerically correct) **〔fact, Test 6〕** |
| Single `linalg.generic` with parallel-only 2-D iteration, sparse adj as ins, dense `[N]` vectors as broadcast ins, sparse output | `failed to legalize unresolved materialization from tensor<..., #SP> to !llvm.ptr` at the function return **〔fact, attempted Test 2 SDDMM variant; same failure on CSR and COO〕** |
| Workaround: same as above but with `linalg.index` + `tensor.extract` for the dense lookups inside the body | Sparsifier-internal assertion: `Merger::makeTensorId: isValidTensorId(t)` **〔fact〕** |

### Untested formulations (the "open question" for GAT P2)

The natural sparse_tensor formulation of GAT's per-edge stage failed.
**Two formulations have not been tested and may resolve the question:**

1. **Matmul-shape with trivial `k=1` reduction.** The upstream `sparse_sampled_matmul.mlir`
   uses 3-D iteration `(i, j, k)` with `k` reduction and dense ins (S sparse, A dense,
   B dense, X dense output). My attempted formulation used 2-D parallel-only. Recasting
   GAT's P2 as a trivial-k matmul might lower where the 2-D form doesn't. Worth ~1 hour.
2. **Pre-pack via `sparse_tensor.assemble`.** Compute `e[E]` as a dense tensor using
   `[E]`-shaped gather + elementwise (no sparse_tensor type involved), then
   `sparse_tensor.assemble (pos, crd), e_values` to bind those values to a
   sparse-typed view of the adjacency. Downstream sparse-tensor elementwise / reduce
   stages then operate on the assembled sparse tensor. This is what
   the COMET research suggests is the canonical bridge from "values computed via
   ordinary ops" to "values living in a sparse type." Worth ~1-2 hours.

**SparseTIR provides existence proof that the pattern is expressible** in
a sparse-tensor compiler: its `sparse_fuse` schedule primitive lets the
iteration "iterate over non-zero (i,j) directly instead of first iterating
over i and then iterating over non-zero j for each i" (paper §4), which
is exactly the iteration we want for sparse-out SDDMM. **〔fact,
[SparseTIR paper](https://arxiv.org/abs/2207.04606)〕** This doesn't
mean MLIR sparse_tensor has the equivalent capability today; it means
the limitation is in MLIR's current pass set, not in sparse-tensor
compilation theory generally.

Until one of these is verified, gnnc's strategic options remain bounded
by ["Design A" (late sparse_tensor introduction)](../experiments/sparsifier-coo-check/README.md#implications-for-gnnc).

## Design implications for gnnc

Four candidate gnnc designs, ordered by ambition:

| Design | Sparse_tensor enters at | Pre-sparse stages | Sparse stages | Achievability |
|---|---|---|---|---|
| **A.** Match PyG/Inductor structure | Just before P5 (final SpMM), via `sparse_tensor.assemble` | P1–P4 as `[E]`-shaped dense ops (gather, elementwise, scatter-reduce) | P5 as `linalg.matmul` on sparse-typed adj | **Verified achievable** — every required op tested |
| **B.** Match DGL structure | At ingress, as the canonical adjacency | None | P2–P5 as separate `sparse_tensor` ops | **Mostly achievable** — depends on resolving GAT P2 SDDMM-shape (open question above) |
| **C.** Match dgNN structure (fused single kernel) | At ingress + one custom MLIR op for P2–P5 | None | P2–P5 fused in one custom op | **Requires custom MLIR op work** — bounded (one op), reuses all other sparse_tensor machinery. The sparse_tensor type appears in the operand signatures of the custom op |
| **D.** Beat dgNN (whole-program / cross-layer fusion) | At ingress + cross-layer scheduling | None | Entire multi-layer forward as one schedule | **Requires significantly more compiler IR** (Index-Tree-like mid-IR or equivalent) |

**〔thought〕** Design A is the floor — what gnnc can achieve with only
the verified MLIR sparse_tensor capabilities. Achieves PyG+Inductor
parity by routing through MLIR codegen instead of Triton. Design B is
the natural next step, contingent on the open SDDMM-shape question.
Design C is dgNN parity with a focused custom-op investment. Design D
is research territory.

## Validated assumptions (with experiment references)

| Assumption | Evidence |
|---|---|
| PyG's `torch.compile` produces 7 Triton + 1 cuBLAS launches per GATConv layer (fullgraph=True, libs disabled, RTX 4070) | [inductor-fusion follow-up](../experiments/inductor-fusion/run-followup.py) |
| 2-layer GAT scales kernel count exactly 2× (zero cross-layer fusion in Inductor) | [inductor-fusion follow-up](../experiments/inductor-fusion/run-followup.py) |
| `aten.nonzero` in PyG's `remove_self_loops` / `add_remaining_self_loops` triggers graph breaks; `fullgraph=True` eliminates them | [dynamo-graph-breaks](../experiments/dynamo-graph-breaks/) |
| A `torch.compile` backend receives one `GraphModule` per FX subgraph; cannot see across breaks | [dynamo-graph-breaks](../experiments/dynamo-graph-breaks/) backend-visibility test |
| MLIR sparse_tensor SpMM produces bit-identical output for CSR and COO encodings on CPU | [sparsifier-coo-check](../experiments/sparsifier-coo-check/) Tests 1, 5 |
| MLIR sparse_tensor sparse-in-place, sparse+sparse, segmented reduce all produce bit-identical CSR/COO outputs | [sparsifier-coo-check](../experiments/sparsifier-coo-check/) Tests 2, 3, 4 |
| GPU codegen via `--sparsifier` fires on CSR (47 ops emitted) but does NOT fire on COO directly | [sparsifier-coo-check](../experiments/sparsifier-coo-check/) Tests 6, 7 |
| `torch.sparse_csr_tensor` is incompatible with `torch.compile` (hard error on `fullgraph=True`, 10 breaks under `fullgraph=False`) — at both the input boundary AND when constructed inside the compiled function via `torch.sparse_csr_tensor(...)` factory | Probes `/tmp/gnnc-probe/probe-pyg-formats.py`, `probe-pyg-formats-2.py`, `probe-aart.py` — should be formalised into `experiments/pyg-input-formats/` |
| `torch.sparse_csr_tensor` IS supported via `torch.export` / `make_fx` / `torch_mlir.fx.export_and_import` — placeholder gets `[layout=torch.sparse_csr]`, MLIR gets `#sparse_tensor.encoding` on the function signature | Probe `/tmp/gnnc-probe/probe-export.py`; corroborated by [experiments/fx-sparsity](../experiments/fx-sparsity/) b-sparse-mm test (project-start finding) |
| The PyTorch PR enabling this is [#117907](https://github.com/pytorch/pytorch/pull/117907) — "propagate sparsity metadata into traced graph" — Aart Bik, landed May 2024. Designed for sparse-compiler backends (i.e., our use case). | [pytorch/pytorch#117907](https://github.com/pytorch/pytorch/pull/117907) |
| `torch.export` traces every PyG default-config we've tested without graph breaks AND without leaving data-dependent ops (`aten.nonzero` etc.) in the resulting graph — unlike `torch.compile(fullgraph=False)` which breaks on the same patterns | `probe-export-pyg.py` and `probe-export-nonzero.py` |
| Lighthouse is migrating default ingress from export-based (`import_from_model`) to compile-based (`MLIRBackend`) per [PR #157 (a7e5ff5)](https://github.com/llvm/lighthouse/commits/main); the path required for sparse_csr input support is the one being deprecated | [Lighthouse changes summary in inductor-fusion experiment](../experiments/inductor-fusion/README.md) |
| Per-layer dispatch when sparse_csr is passed to PyG conv + exported via `torch_mlir.fx`: GCNConv produces `torch.aten._sparse_mm(%adj_sparse, %dense)` directly (end-to-end ready for sparsifier SpMM path); SAGEConv same plus minor `crow_indices` extraction for root-features handling; GATConv preserves sparse encoding on the signature but body decomposes via `crow_indices`/`col_indices` extractions + gather/scatter | `/tmp/gnnc-probe/probe-pyg-sparse-export.py` |
| `torch_geometric.EdgeIndex` produces identical Inductor kernel counts to plain LongTensor under `fullgraph=True`, with 2 extra runtime aten dispatches | `probe-pyg-formats.py` |
| EdgeIndex requires `fullgraph=True` to be break-free even with `add_self_loops=False` (vs plain LongTensor which is 0 breaks under either) | `probe-pyg-formats-2.py` |
| In-MLIR `sparse_tensor.convert COO → CSR` produces identical downstream GPU code to native CSR | [sparsifier-coo-check](../experiments/sparsifier-coo-check/) Test 7 |
| GAT's per-edge `e_ij` compute under PyG is via gather + elementwise on `[E]` dense tensors, not via a sparse_tensor type | [inductor-fusion dumps](../experiments/inductor-fusion/dumps/) (gatconv-nolibs.unit2.py shows `aten.index_select` then `aten.add` then `aten.leaky_relu` on `[E]`-shaped tensors) |
| PyG officially documents `add_self_loops=False, normalize=False` + data-side transforms as the compile-friendly path | [PyG compile docs](https://pytorch-geometric.readthedocs.io/en/2.6.1/advanced/compile.html), confirmed by [dynamo-graph-breaks](../experiments/dynamo-graph-breaks/) |
| `EdgeIndex` (PyG 2.5+) is a `torch.Tensor` subclass over `[2, E]` with lazy rowptr/colptr caches; PyG 2.5 release notes commit to it as the eventual replacement for `torch_sparse.SparseTensor` | [PyG 2.5.0 release notes](https://github.com/pyg-team/pytorch_geometric/releases/tag/2.5.0), [EdgeIndex source](https://github.com/pyg-team/pytorch_geometric/blob/master/torch_geometric/edge_index.py) |
| COMET's sparse-tensor compilation uses the same Chou-Kjolstad level-format theory as MLIR sparse_tensor (D/CU/CN/S vs dense/compressed/compressed-nonunique/singleton); construction boundary is `ta.spTensor_construct` from dense `pos`/`crd`/`val` arrays | Tian et al., "A High-Performance Sparse Tensor Algebra Compiler in Multi-Level IR," LLVM-HPC 2021, [arXiv:2102.05187](https://arxiv.org/abs/2102.05187); [COMET source](https://github.com/pnnl/COMET) |

## Open questions — experiments to run before deeper design commitments

In priority order. Each is bounded (hours, not days).

### Cornerstone questions for design selection

1. **Does the matmul-shape formulation of GAT's P2 lower?** Recast as 3-D iteration `(i, j, k)` with trivial `k=1` reduction, dense ins (`α_src`, `α_dst`), sparse adj for sampling, sparse output. If this lowers, **Design B is achievable.** ~1 hour. Should produce a new test in `experiments/sparsifier-coo-check/` or a sibling experiment.

2. **Does `sparse_tensor.assemble` with externally-computed `[E]` values work end-to-end?** Compute `e[E]` via ordinary `[E]`-shaped MLIR ops, then `assemble` into a sparse tensor; verify downstream sparse-tensor elementwise + segmented reduction (the GAT softmax pipeline) accept the assembled tensor. If yes, **Design A → B transition is mechanical.** ~1-2 hours.

### Performance-grounding questions

3. **Run dgNN locally on RTX 4070 + ogbn-arxiv** to ground the ~3× headline number in measured ms on our hardware. Removes the "back-of-envelope" caveat from the [pyg-baseline writeup](../experiments/pyg-baseline/README.md#L244-L250). ~half-day setup.

4. **Re-run inductor-fusion at realistic scale (Cora 10K edges, ogbn-arxiv 1.2M edges).** The toy 100-node measurement hides DRAM-intermediate cost. Same kernel-count structure expected; absolute timing changes meaningfully. ~half-day.

5. **DGL g-SpMM kernel inspection.** Confirm the "one fused kernel" claim for DGL's GCN and the "edge-softmax + g-SpMM" claim for GAT. Run with NVIDIA Nsight Systems to count kernel launches per layer. Compare against our PyG+Inductor measurement. ~half-day.

### Capability questions worth knowing

6. **MLIR sparse_tensor sparse-output elementwise with `sparse_tensor.binary`.** GAT's P3b (exp(e - max[dst])) needs to combine a per-edge sparse value with a per-dst dense gather. The `sparse_tensor.binary` op was tested for two sparse inputs (Test 3); does it work with sparse + dense? Not exercised in our experiments. ~1 hour.

7. **Multi-layer fusion via `linalg.generic` chaining.** What does linalg-fusion across two consecutive `linalg.matmul` (sparse, sparse) actually do? Direction of [Design D]. ~1 hour to probe.

### Long-tail framework validation

8. **DGL's storage format and fusion structure** — verified 2026-05-27 against paper and source. Findings folded into the tables above.
9. **dgNN's published fusion structure** — verified against [arxiv 2110.09524](https://arxiv.org/abs/2110.09524) and [dgN repo source](https://github.com/dgSPARSE/dgNN). Findings folded above.
10. **SparseTIR's composable formats and `sparse_fuse` primitive** — verified against [arxiv 2207.04606](https://arxiv.org/abs/2207.04606). Findings folded above.
11. **〔NEW〕 Investigate whether MLIR sparse_tensor has any equivalent of SparseTIR's `sparse_fuse`** — search the dialect ops + recent commits for any "iterate over nonzero coordinates directly" schedule primitive or proposal. ~1 hour, may resolve the SDDMM-shape question without needing the experiment workarounds.

### Performance follow-ups beyond what was originally listed

12. **Compare DGL GAT (3-kernel) vs dgNN GAT (1-kernel) wall-clock on RTX 4070** to localize where the ~3× gap actually lives — is it all in the `α` DRAM round-trip between `edge_softmax` and `update_all`, or are there other contributions? Half-day.
13. **DF-GNN super-node-aware dispatch** (high-degree → edge-parallel PMF, low-degree → warp-balanced node-parallel SMMF) as a v2/v3 reference point. Read the [DF-GNN paper](https://arxiv.org/abs/2411.16127) and decide whether to track this for the project's medium-term roadmap. Reading-only; no experiment yet.

### Formalize the PyG input-format probes

14. **Promote the throwaway PyG-format probes** into `experiments/pyg-input-formats/`. Captures: per-format compile/break behavior, Inductor kernel structure for compiled formats, **and** export-path sparse-tensor metadata propagation (the gnnc-relevant path). Should include:
    - All three PyG input formats (plain LongTensor, EdgeIndex, sparse_csr_tensor)
    - Both ingress paths (`torch.compile` and `torch.export` / `torch_mlir.fx`)
    - GAT, GCN, SAGE cases
    - The verbatim MLIR output from the export path showing `#sparse_tensor.encoding` propagation
    ~2 hours to formalize the existing probes.

15. **〔NEW, cornerstone-grade〕 Build a second ingress path for gnnc that uses `torch.export` directly** (or `torch_mlir.fx.export_and_import`), not `torch.compile` via Lighthouse's `MLIRBackend`. This is required for any PyG model that takes a `torch.sparse_csr_tensor` as input — Lighthouse's `MLIRBackend` will fail to wrap such inputs. Investigate: does Lighthouse have an `MLIRBackend` variant that takes an already-exported FX graph (skipping the `torch.compile` wrapping)? If yes, plumb it. If no, this is a custom ingress path for gnnc — half-day to a day of work depending on Lighthouse's API surface.

16. **〔NEW, cornerstone-grade — upstream relationship〕 Engage with Lighthouse on the export-path deprecation.** Either contribute to keeping `import_from_model` as a supported path (with a stable API), or pin a Lighthouse commit that has both paths and plan to either fork or migrate away when they remove it. The PR to watch is the follow-up to [#157](https://github.com/llvm/lighthouse/pull/157) that flips the default. Worth a Discord/issue conversation with rengolin / rolfmorel about whether sparse-tensor-input support is in their roadmap or if gnnc is the only consumer of that ingress path.

## References

### Frameworks

- **PyG**: [pyg-team/pytorch_geometric](https://github.com/pyg-team/pytorch_geometric), [docs](https://pytorch-geometric.readthedocs.io/), [EdgeIndex source](https://github.com/pyg-team/pytorch_geometric/blob/master/torch_geometric/edge_index.py)
- **DGL**: [dmlc/dgl](https://github.com/dmlc/dgl). Paper: Wang et al., "Deep Graph Library: A Graph-Centric, Highly-Performant Package for Graph Neural Networks," [arXiv:1909.01315](https://arxiv.org/abs/1909.01315). FeatGraph backend: Hu et al., "FeatGraph: A Flexible and Efficient Backend for Graph Neural Network Systems," SC 2020, [arXiv:2008.11359](https://arxiv.org/abs/2008.11359). Key source files: [graphconv.py](https://github.com/dmlc/dgl/blob/master/python/dgl/nn/pytorch/conv/graphconv.py), [gatconv.py](https://github.com/dmlc/dgl/blob/master/python/dgl/nn/pytorch/conv/gatconv.py), [heterograph.py format methods](https://github.com/dmlc/dgl/blob/master/python/dgl/heterograph.py#L6090)
- **dgNN**: Zhang et al., "Understanding GNN Computational Graph: A Coordinated Computation, IO, and Memory Perspective," MLSys 2022, [arXiv:2110.09524](https://arxiv.org/abs/2110.09524). Repo: [dgSPARSE/dgNN](https://github.com/dgSPARSE/dgNN). Operators: [fused_gatconv.py](https://github.com/dgSPARSE/dgNN/blob/main/dgNN/operators/fused_gatconv.py)
- **DF-GNN**: "DF-GNN: Dynamic Fusion Framework for Attention Graph Neural Networks on GPUs," MLSys 2025, [arXiv:2411.16127](https://arxiv.org/abs/2411.16127)
- **SparseTIR**: Ye et al., "SparseTIR: Composable Abstractions for Sparse Compilation in Deep Learning," ASPLOS 2023, [arXiv:2207.04606](https://arxiv.org/abs/2207.04606). Repo: [uwsampl/SparseTIR](https://github.com/uwsampl/SparseTIR)

### MLIR sparse_tensor / sparse-tensor compilation

- Chou, Kjolstad, Amarasinghe, "Format Abstraction for Sparse Tensor Algebra Compilers," POPL 2018, [DOI](https://dl.acm.org/doi/10.1145/3276493) — defines the level-format vocabulary
- Bik, Koanantakool, Wijfels, Kjolstad, "Compiler Support for Sparse Tensor Computations in MLIR," ACM TACO 2022, [DOI](https://dl.acm.org/doi/10.1145/3544559) — MLIR sparse_tensor landing paper
- [MLIR sparse_tensor dialect docs](https://mlir.llvm.org/docs/Dialects/SparseTensorOps/)
- Tian, Guo, Li, Ren, Kestor, "A High-Performance Sparse Tensor Algebra Compiler in Multi-Level IR," LLVM-HPC 2021, [arXiv:2102.05187](https://arxiv.org/abs/2102.05187) — COMET
- Peng, Ashraf, Guo, Tian, Kestor, "Automatic Code Generation for High-Performance Graph Algorithms," PACT 2023 — COMET + Index Tree dialect

### Project experiments referenced

- [experiments/inductor-fusion/](../experiments/inductor-fusion/) — PyG GAT kernel counts under torch.compile
- [experiments/dynamo-graph-breaks/](../experiments/dynamo-graph-breaks/) — PyG conv graph-break inventory and backend visibility
- [experiments/pyg-baseline/](../experiments/pyg-baseline/) — eager + compiled timing baseline, dgNN gap discussion
- [experiments/fx-sparsity/](../experiments/fx-sparsity/) — torch-mlir FX importer sparsity preservation
- [experiments/gatconv/](../experiments/gatconv/) — GATConv FX → linalg-on-tensors characterization
- [experiments/gpu-sparsifier/](../experiments/gpu-sparsifier/) — MLIR sparse_tensor GPU codegen validation (CSR)
- [experiments/gat-gpu-codegen/](../experiments/gat-gpu-codegen/) — GAT-shape kernel GPU codegen target
- [experiments/sparsifier-coo-check/](../experiments/sparsifier-coo-check/) — MLIR sparse_tensor COO/CSR parity and SDDMM-shape failure modes
