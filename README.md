# GNNC

An experimental MLIR-based compiler for Graph Neural Networks.

This is a learning/proof-of-concept project. There's been a bunch of work on GNN compilers, but the landscape has gradually settled into PyG as a home for most users and researchers, especially for new models, and either bespoke implementations or a gradually-fading DGL.

One of the interesting parts of GNN compilers to me has always been aggressive kernel fusion. Most research efforts have tried it, and DGL certainly leveraged it in the practical space. Ultiamtely, though, most tools (the TVM folks excepted) relied on hand-tuned, hardcoded monolithic GPU kernels to carry the day. PyG, notably though, hasn't really gone down that path very far, and I'm casually interested in the compiler alternative for getting the best of both worlds: how far we can go with IR-level fusion and better codegen while retaining the benefits of PyG (and perhaps more importantly, its ecosystem and users). Despite not really being designed for it, triton has had a fair amount of success with it in more mainstream models, and I don't think the community has really pushed the idea as far as it can go.

In any case, that's what this project is. I took a stab at this problem back in 2020, but a lot of the pieces just weren't ready. Aart and the folks behind the `sparse_tensor` dialect deserve a lot of the credit for the fact that is no longer true, but Torch itself has made a lot of strides in tracing, compilation, and integration, which have helped tremendously. I'm also looking forward to taking advantage of MLIR's Lighthouse effort, which is still young but shaping up well.

## Architecture

**PyTorch Geometric → torch-mlir → MLIR (linalg → sparse-tensor) → GPU/CPU.**

Pipeline: a PyG model is FX-imported to MLIR, lowered by a pass recipe,
JIT-executed, and checked against PyG running normally.


## Common commands

First time after clone (the multi-GB builds; the devcontainer runs
`uv sync --extra dev` automatically):

```bash
git submodule update --init --recursive
uv sync --extra dev
bash tools/build-llvm.sh                      # ~30 min cold; ccache after
bash tools/build-torch-mlir.sh
bash tools/build-gnnc.sh                       # gnnc's C++ MLIR passes
bash tools/link-stack.sh                       # link mlir/torch-mlir/lighthouse into the venv
bash tools/build-pyg-libs.sh                   # optional: PyG baseline only
```

The Python stack (mlir / torch-mlir / lighthouse) is linked into the venv by
`tools/link-stack.sh`, so the CLIs, pytest, and the editor import it directly —
no `PYTHONPATH`. Re-run it only after the venv is recreated. `source tools/env.sh`
is optional: it just puts the LLVM tools (`mlir-opt`, `FileCheck`, …) on your PATH
for interactive use.

Run / test:

```bash
gnnc-bench --model gcn --dataset cora --recipe cpu/sparse-basic   # compile + run + compare
lit test/                                      # MLIR pipeline + pass lit tests
pre-commit run --all-files                     # ruff + hygiene + lit + pytest (in-container)
```
