# Short-Term Tasks: Resolving Unknowns

Two characterization tests need to be resolved before the rest of the sprint plan can be trusted. Both are nominally an afternoon of work each. Either confirms the plan or saves a week downstream.

These tasks happen **before** week 1 properly begins. Call this day 0.

---

## Task 1: Characterize torch-mlir FX-importer sparsity behavior

**Question being answered:** Does torch-mlir's FX importer preserve enough sparsity-relevant information for Python-level rewrites to produce usable sparse `linalg.generic` ops, or does the trace flatten sparse operations into dense gather/scatter beyond reasonable recovery?

**Why it matters:** If torch-mlir's output is usable as-is (or with light adapter logic), week 1's v0 plan stands. If it's bad, week 1 changes to writing a smaller hand-rolled FX-graph-to-MLIR converter for the PyTorch op subset we need, which is more work but tractable. Either way, we need to know on day 0, not in week 2.

**Procedure:**

1. Build a 10-line GCN forward pass in PyG (one `GCNConv` layer, small synthetic graph, no training).
2. Trace it through `torch_mlir.fx.export_and_import` (or current equivalent — check the torch-mlir docs at the time, the FX API has evolved).
3. Inspect the resulting MLIR at three levels:
   - Raw `torch` dialect output
   - After `torch-to-linalg` lowering
   - After any available sparse-related conversion passes
4. Check specifically: is the adjacency operation represented in a way that a downstream pass could annotate with a sparse encoding, or is it irretrievably dense + scatter/gather?
5. Repeat with a `torch.sparse.mm` call wrapped around a `torch.sparse_csr_tensor` to see what the "explicit sparse" path produces.

**Pass criteria:**

- **Green:** torch-mlir produces `linalg.generic` (or equivalent) where a sparse encoding annotation on one operand would make the operation lower cleanly through the sparsifier. v0 plan stands.
- **Yellow:** torch-mlir output requires non-trivial rewriting to recover sparsity, but the rewrite is mechanical and bounded. v0 plan stands with an additional adapter pass; budget half a week.
- **Red:** torch-mlir flattens enough that recovery is itself a research problem. Plan changes — replace torch-mlir with a hand-rolled FX→MLIR converter for the operator subset we need. Adds roughly a week to week 1; cascade into weeks 2/3.

**Deliverable:** A short writeup (one page) with the MLIR dumps at each stage, the assessment color, and any adapter sketches if needed.

---

## Task 2: Characterize sparsifier GPU codegen state

**Question being answered:** Does the sparse-tensor dialect's GPU codegen path (`sparse-gpu-codegen` or its current equivalent) produce functional GPU code for a basic SpMM on our target machine, at the llvm-project commit torch-mlir currently pins?

**Why it matters:** The sparse-tensor dialect's GPU story has been moving for two years and depends on `sparse-gpu-codegen`, the `gpu` dialect's NVVM lowering, and the runtime wrappers all being in working states simultaneously. Version skew between torch-mlir's known-good commit and the working state of the GPU path could land us in a broken window. Week 2's "GPU comes online" milestone assumes this works.

**Procedure:**

1. Hand-write a sparse `linalg.generic` for SpMM directly in MLIR — no PyTorch, no torch-mlir. Two tensors: a CSR-encoded sparse matrix, a dense matrix, dense output.
2. Run the canonical pipeline: `sparsifier` → `gpu-map-parallel-loops` → `convert-gpu-to-nvvm` → LLVM.
3. Execute through `mlir-runner` with the CUDA runtime wrappers loaded.
4. Verify correctness against a CPU run of the same operation.

**Pass criteria:**

- **Green:** end-to-end execution works, output matches CPU. GPU path is viable. Week 2 plan stands.
- **Yellow:** path works for the simplest case but breaks on something we'll need (mean/max reductions, multi-dim feature tensors, etc.). Document what breaks; week 2 plan needs the broken cases as known issues to either fix or work around.
- **Red:** the GPU path is broken at our llvm-project commit. Options: (a) bump torch-mlir to a newer known-good commit if one exists, (b) defer GPU to week 3 or later and aim CPU-only for weeks 1–2, (c) escalate — file a bug with the sparse-tensor dialect maintainers (the MPACT/Aart-Bik crowd, accessible via LLVM Discourse).

**Deliverable:** A short writeup with the MLIR source used, the commands run, the result, and the assessment color.

---

## Task 3: Confirm baseline measurement methodology

**Question being answered:** What exactly are we measuring "PyG performance" against, and on what hardware?

**Why it matters:** "Beat PyG" is the project's success criterion. If the measurement methodology is sloppy, the result is meaningless regardless of whether the compiler works.

**Procedure:**

1. Install `pytorch-geometric` via standard `pip install` on the target machine.
2. Run a GCN forward pass on OGB-arxiv, default PyG path (no manual tuning, no Inductor, no compile).
3. Record: wall-clock time per forward pass (averaged over N runs with warmup), peak GPU memory, what backend was used (which path through PyG's dispatch — `MessagePassing` + `torch_scatter`, `SparseTensor` + `torch_sparse`, `EdgeIndex` + cuSPARSE).
4. Repeat for GAT and SAGE.
5. Document hardware (GPU model, driver version, CUDA version), PyTorch version, PyG version, torch-scatter/torch-sparse versions.

**Deliverable:** A baseline numbers file that becomes the reference for every subsequent performance claim. Update it if any baseline component changes.

This is mostly a measurement-hygiene task, not a risk-resolution task — but doing it on day 0 prevents the week-3 scenario where "we beat PyG by 20%" turns out to mean "we beat a misconfigured PyG by 20%."

---

## Decision gate

After all three tasks, before starting week 1 proper, make an explicit go/no-go assessment:

- All three green → execute the sprint plan as written.
- Any yellow → adjust the affected week's scope before starting it. Document the adjustment in the project summary.
- Any red → stop and re-plan. The sprint may still be viable but the structure will be different.

Time budget for day 0: one day, hard cap. If any task is taking more than half a day, that itself is a signal — write up what you've learned so far and treat it as a partial result rather than blocking on completeness.
