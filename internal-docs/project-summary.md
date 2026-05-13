# GNN AOT Compiler — Project Summary

## Goal

Prototype an ahead-of-time compiler for Graph Neural Networks built in PyTorch Geometric (PyG), targeting the MLIR sparse-tensor dialect as an intermediate representation, with the aim of replacing PyG's supporting libraries (`torch_scatter`, `torch_sparse`, and the cuSPARSE-backed `EdgeIndex` path) with generated code.

The ultimate goal is to **beat PyG's deployed implementation on GPU**, with credibility primarily on GAT (where fused attention-aggregation kernels are where library-quality implementations beat compose-from-primitives baselines). Matching PyG on GCN/SAGE is the realistic 3-week target; beating PyG on GAT is the project's thesis.

## Context

This project is conceived as a Lighthouse-style starting point — using `llvm/lighthouse` as the seed for harness, ingress, and recipe patterns, then forking when load-bearing dialect code becomes necessary. The relationship to Lighthouse is structural (we adopt its layout and harness patterns) rather than contributory (we don't intend to upstream the GNN dialect itself).

Lighthouse's no-load-bearing-code rule means that as long as we operate at the Python-rewrite + recipe + pass-pipeline level, we're within its rules. The moment we introduce a `gnn.*` dialect with verifiers, lowering passes, and fusion rules, we're outside, and the project becomes a satellite repo that depends on llvm-project at a known commit — the IREE-style pattern.

A prior attempt at this project three years ago was stymied by TorchScript limitations and the immaturity of the sparse-tensor dialect. Both have improved qualitatively since.

## Key Design Decisions

### Ingress strategy

PyG → torch-mlir FX importer → torch dialect → linalg dialect. Reject the alternative of intercepting at PyG level and rewriting message-passing to explicit SpMM before tracing — that discards the operation's semantic identity (aggregation with a specific reduction over a specific edge structure) and bakes in format and op-shape choices that should be compiler decisions.

Preserve operation semantics through the pipeline by lifting them into a high-level `gnn.*` dialect that has not yet committed to a sparse representation or to whether the operation is executed as a sparse linear algebra operation at all. Format selection and lowering strategy become passes, not ingress decisions.

### Dialect shape

Anticipated operations:

- `gnn.propagate` — core message-passing op, parameterized by reduction kind (sum/mean/max/min), taking edge index, node features, optional edge features, optional edge weights.
- `gnn.gather_edges` / `gnn.scatter_nodes` — for layers where message construction and reduction should be separable.
- `gnn.attention_aggregate` — fused attention + aggregation for GAT-class layers.
- `gnn.sddmm` — sampled dense-dense matrix multiplication, needed for sampling-style workloads and attention coefficients.
- `gnn.edge_softmax` — segment-softmax along edges grouped by destination node.

Edge index initially encoded as `tensor<?x2xindex>` (PyG-style); migrate to a graph type only if analyses keep recomputing structural information that should be cached in types. The sparse-tensor dialect's history (started simpler, grew the encoding attribute) is the precedent.

### Fusion division of labor

The `gnn` dialect owns the "which sparse abstraction" decision. The sparse-tensor dialect (via the sparsifier) owns the "how to iterate it" decision. The interface between them is an annotated `linalg.generic`. Once `gnn.propagate` is lowered to a `linalg.generic` with a chosen sparse encoding, the sparsifier handles fusion of elementwise message transforms into the loop nest — this is the case where the sparsifier excels (sparse-in, dense-out with elementwise composition).

Where the sparsifier's coverage thins out — sparse-in-sparse-out chains, segmented operations like edge-softmax in the middle of an SDDMM→softmax→SpMM pipeline, reductions whose structure doesn't match sparse iteration order — fusion has to happen at the `gnn.*` level before lowering. GAT is the canonical case here.

### Scope decisions

- **Inference only.** Training (and the CSR/CSC dual-format trick for forward/backward) is deferred.
- **Transduction.** Graph structure is not known at compile time; the compiled kernel accepts a graph at runtime. This rules out graph-specific compile-time optimizations (degree bucketing baked into code, structure-specific reordering) but is the realistic deployment scenario.
- **NVIDIA GPU primary target.** Sparse tensor cores (2:4) are useless for graph-scale sparsity (k:N where k is single-digit, N is millions), so the realistic GPU codegen story is CUDA cores with careful memory access — same regime cuSPARSE operates in for the general case.
- **FP32 throughout.** Mixed precision deferred.
- **No graphformer.** Computationally too far from message-passing to share infrastructure.

### Alternatives mechanism

Two layers of switchability, motivated by wanting iterative development without locking in dialect choices:

1. **Dialect-presence axis.** v0 has no `gnn.*` dialect — Python-level rewrites land directly in `linalg.generic` with sparse encodings, exercising only upstream MLIR. v1+ introduces the dialect. Both versions produce the same `linalg.generic` shapes, so golden outputs match across versions and correctness is comparable.
2. **Strategy axis.** A recipe is a named pass pipeline plus optional pre-processing. Multiple recipes for the same model are selectable via a flag (`--recipe v1_gnn_csr_spmm`). Same model, same goldens, different lowering. Adding a new strategy is adding a recipe file.

## Models

- **GCN** (week 1) — simplest case, pure sum-aggregation, exercises basic SpMM path.
- **SAGE** (week 2) — structurally similar to GCN with different normalization; free additional model.
- **GAT** (week 3) — fusion-stressing case, project's actual thesis test.

No fourth model. SDDMM as a standalone op covers the "sampling support" data-axis requirement without requiring a new architecture.

## Datasets

- **Cora** (2.7k nodes, 5.3k edges) — week 1 development scale, fast iteration.
- **OGB-arxiv** (170k nodes, 1.2M edges) — primary target. Small enough to debug, large enough for measurable performance differences, well-understood baselines.
- **OGB-products** (2.4M nodes, 61M edges) — stretch target if everything works by end of week 3. Where representation choices start to matter visibly.

OGB loaders are stable; no new dataset infrastructure required.

## Baselines

The "beat PyG" claim is specifically against the `pip install pytorch-geometric` deployment path — `MessagePassing` calling `torch_scatter` for general message passing, `SparseTensor` calling `torch_sparse` for SpMM-shaped pieces. Same backend in practice. Inductor is explicitly **not** the baseline — it's a slow path. The cuSPARSE-backed `EdgeIndex` path is a secondary baseline of interest for the SpMM cases.

`dgNN`'s fused-attention CUDA kernel is the performance reference for GAT specifically. Matching it is hard; beating it is the project's thesis.

## Architectural Comparison (prior art)

- **Graphiler** (MLSys 2022) operates above our dialect — frontend optimizer over a message-passing data flow graph (MP-DFG) abstraction, then hands off to TorchScript/TVM for codegen. Our `gnn.propagate` is structurally analogous to their MP-DFG node. Their fusion rules (especially for "linear-decomposable" message functions) are a reasonable starting catalog for `gnn.*` rewrites. Divergence: they don't make format choices; TVM does.
- **dgNN** is hand-written CUDA fused kernels exposed through DGL, not a compiler. Performance baseline for GAT. Their kernel-design lesson — edge-parallel for high-degree nodes, node-parallel for low-degree, with degree bucketing — is the kind of optimization our COO+segment-reduce lowering would want.
- **MPACT** (Aart Bik's MLIR sparse-compiler playground) is the closest sibling structurally — same dialect, same sparsifier philosophy, same MLIR-native approach. Different domain (HPC-style sparse kernels, not GNN). The natural collaborator: improvements we drive into the sparse-tensor dialect would land alongside MPACT's work.

The intersection no prior work simultaneously occupies: format-choice-as-compiler-decision + MLIR-native codegen + GAT-class fusion. That intersection is this project's thesis.

## Sprint Structure

Three weeks, three sequential MWEs:

- **Week 1 — v0, narrow.** GCN inference, CPU, Cora. Pure Python ingress, no `gnn` dialect, sparse `linalg.generic` directly, sparsifier handles lowering, `mlir-runner` executes, golden compare against PyG-eager.
- **Week 2 — v1, dialect appears, GPU online.** `gnn.propagate` defined. One lowering: CSR-SpMM. GPU lowering through `gpu`→NVVM. GCN and SAGE running. Goldens match v0.
- **Week 3 — v2/v3, the interesting cases.** `gnn.attention_aggregate` for GAT. SDDMM as separate op. Possibly v2 (COO + segment-reduce) as alternative `gnn.propagate` lowering.

## Risks

- **torch-mlir sparsity propagation** — the FX importer may flatten sparse operations into dense gather/scatter in ways that defeat downstream sparsity recovery. Day-1 characterization test.
- **Sparsifier GPU codegen maturity** — version skew between torch-mlir's known-good llvm-project commit and the working state of `sparse-gpu-codegen` could land us in a broken window. Day-1 characterization test.
- **GAT performance gap** — matching dgNN in 3 weeks is unlikely. "GAT runs, correct, 3× slower than dgNN, we know which optimization is missing" is a successful outcome.
- **Sprint compounding** — weeks 2 and 3 each depend on week 1's outputs. Any week-1 slip cascades.

## Deferred (post-sprint)

Training and backward pass; CSR/CSC dual-format optimization; actual sampling (just SDDMM support); precision modes (FP16/BF16, mixed); cost-model-driven strategy selection; autotuner; multi-GPU; graphformer; OGB-papers100M-scale data (doesn't fit on one GPU anyway).
