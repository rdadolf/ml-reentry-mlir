# third_party — pinned submodule commits

Both submodules build out-of-tree against build directories on the cache mount
(`$GNNC_CACHE_DIR/build/{llvm,torch-mlir}`). Sources are versioned here so the
build is reproducible.

## Current pins

| Submodule    | Commit                                     | Source of truth                                              |
|--------------|--------------------------------------------|--------------------------------------------------------------|
| llvm-project | `ea2f50817fa32560f8fac227b58d6a2a9626df3b` | torch-mlir HEAD's `externals/llvm-project` submodule pointer |
| torch-mlir   | `90fc2151dbc3d70dbd36fa595dcf817fccdc6ea9` | torch-mlir `main` HEAD at time of repo init                  |

**The two commits MUST stay aligned.** torch-mlir builds against the LLVM API
at the commit it pins; an llvm-project pin that doesn't match torch-mlir's
externals will produce subtle API/version mismatches at link or load time.

## Bumping the pins

```bash
# 1. Pick the new torch-mlir commit (usually current main HEAD).
new_tm=$(git ls-remote https://github.com/llvm/torch-mlir.git refs/heads/main | cut -f1)

# 2. Read the llvm-project pointer recorded at that commit.
new_llvm=$(git -C third_party/torch-mlir fetch --quiet origin $new_tm && \
           git -C third_party/torch-mlir ls-tree $new_tm:externals llvm-project | \
           awk '{print $3}')

# 3. Update both submodules.
( cd third_party/torch-mlir && git checkout "$new_tm" )
( cd third_party/llvm-project && git fetch && git checkout "$new_llvm" )

# 4. Update this file with the new SHAs, then commit.
```

After bumping: clear the LLVM build (`rm -rf $GNNC_CACHE_DIR/build/llvm`) and
rebuild. ccache will absorb most of the cost for small bumps; a major version
jump means a near-full rebuild.

## Build flow

- `tools/build-llvm.sh` — configure and build LLVM (mlir, sparse-tensor,
  GPU/NVVM). Writes to `$GNNC_CACHE_DIR/build/llvm`.
- `tools/build-torch-mlir.sh` — configure and build torch-mlir against the
  freshly-built LLVM. Writes to `$GNNC_CACHE_DIR/build/torch-mlir`.

Source `tools/env.sh` to put the resulting `mlir-opt`, `mlir-runner`,
`FileCheck`, etc. on `PATH` and torch-mlir's Python package on `PYTHONPATH`.
