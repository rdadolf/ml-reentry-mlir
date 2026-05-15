# third_party — pinned submodule commits

Submodules build out-of-tree against build directories on the cache mount
(`$GNNC_CACHE_DIR/build/...`) where applicable. Sources are versioned here so
the build is reproducible.

## Current pins

| Submodule         | Commit                                     | Source of truth                                              |
|-------------------|--------------------------------------------|--------------------------------------------------------------|
| llvm-project      | `ea2f50817fa32560f8fac227b58d6a2a9626df3b` | torch-mlir HEAD's `externals/llvm-project` submodule pointer |
| torch-mlir        | `90fc2151dbc3d70dbd36fa595dcf817fccdc6ea9` | torch-mlir `main` HEAD at repo init                          |
| pytorch_scatter   | `edeb04224f80f44c4765a05d34fbdde154df057b` | master HEAD at time of PyG-baseline build                    |
| pytorch_sparse    | `2be752eb2e12d4c76d29c7a11d0f0b77cfd9ff45` | master HEAD at time of PyG-baseline build                    |
| pyg-lib           | `0a71671279582375dd9e7467f83721b161f87b3c` | master HEAD at time of PyG-baseline build                    |
| lighthouse        | `6982ad3cfdeb216ec614ae452221ff2c3f6d86fa` | `llvm/lighthouse` `main` HEAD at integration time            |

### llvm-project / torch-mlir alignment

**These two commits MUST stay aligned.** torch-mlir builds against the LLVM API
at the commit it pins; an llvm-project pin that doesn't match torch-mlir's
externals produces subtle API/version mismatches at link or load time.

### PyG-library set (pytorch_scatter / pytorch_sparse / pyg-lib)

These are the `pip install pytorch-geometric` deployment-path libraries. They
are source-built (not wheel-installed) because the published wheels at
`https://data.pyg.org/whl/` lag torch's nightly cu130 releases; we pin to
master HEAD so the build reflects upstream's most-current compatibility with
the torch version in our venv.

These pins are decoupled from the torch-mlir/llvm-project pair. Bumping them
is independent.

### lighthouse

Consumed as an in-tree submodule on `PYTHONPATH` (see `tools/env.sh`), not
pip-installed and not built — it is pure Python operating at the
recipe/pipeline level. It imports `mlir` / `torch_mlir`, which resolve to
our source builds. We deliberately do **not** use lighthouse's eudsl
`mlir-python-bindings` wheel dependency (that path lacks
`libmlir_cuda_runtime.so`; see
`internal-docs/lighthouse-integration-research.md`). The pin is decoupled
from every other submodule; bump it deliberately (its Python APIs are not
stable — see upstream issue #139).

## Bumping the pins

### llvm-project + torch-mlir (must move together)

```bash
new_tm=$(git ls-remote https://github.com/llvm/torch-mlir.git refs/heads/main | cut -f1)
new_llvm=$(git -C third_party/torch-mlir fetch --quiet origin $new_tm && \
           git -C third_party/torch-mlir ls-tree $new_tm:externals llvm-project | \
           awk '{print $3}')
( cd third_party/torch-mlir && git checkout "$new_tm" )
( cd third_party/llvm-project && git fetch && git checkout "$new_llvm" )
```

Then clear the build (`rm -rf $GNNC_CACHE_DIR/build/{llvm,torch-mlir}`) and
rebuild. ccache absorbs most of the cost for small bumps.

### PyG-library set (each independently)

```bash
for d in pytorch_scatter pytorch_sparse pyg-lib; do
    ( cd third_party/$d && git fetch && git checkout origin/master )
done
git -C third_party/pyg-lib submodule update --init --recursive
bash tools/build-pyg-libs.sh    # reinstall into /x/cache/venv
```

### lighthouse (independent)

```bash
( cd third_party/lighthouse && git fetch && git checkout origin/main )
```

No rebuild needed (pure Python). Re-run the smoke test
(`test/integration/lighthouse_smoke.py`) to catch API drift before
committing the new pointer.

In all cases, update the SHAs in the table above and commit.

## Build flow

- `tools/build-llvm.sh` — out-of-tree LLVM (mlir, sparse-tensor, GPU/NVVM)
  into `$GNNC_CACHE_DIR/build/llvm`.
- `tools/build-torch-mlir.sh` — out-of-tree torch-mlir against the just-built
  LLVM, into `$GNNC_CACHE_DIR/build/torch-mlir`.
- `tools/build-pyg-libs.sh` — source-build and install pytorch_scatter,
  pytorch_sparse, and pyg-lib into the active uv venv
  (`$UV_PROJECT_ENVIRONMENT=/x/cache/venv`). No persistent build dir; pip's
  ephemeral build is used because incremental rebuilds aren't a hot path
  for these.

Source `tools/env.sh` to put the resulting `mlir-opt`, `mlir-runner`,
`FileCheck`, etc. on `PATH` and the MLIR, torch-mlir, and lighthouse
Python packages on `PYTHONPATH`. The PyG libraries install as regular
Python packages and don't need PYTHONPATH plumbing.
