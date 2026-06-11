// Verifies that the sparsifier's GPU codegen path actually puts the SpMM on
// the device — not the cuSPARSE library fallback, not host loops.
//
// Input is the pinned GCN linalg-on-tensors reference (two SpMM-shape
// matmuls on a CSR adjacency, plus the dense projection + log_softmax tail).
// The sparsifier options here are the same ones gpu/sparse-basic.yaml
// passes; spelled out separately so this test catches sparsifier-behavior
// drift independent of the recipe YAML.
//
// What "isn't running host-side" means here:
//   gpu.binary @sparse_kernels    — the CUBIN+PTX fatbinary is embedded
//   nvvm.target<chip = "sm_89">   — the GPU target attached
//   gpu.launch_func               — at least one kernel launch survives
//
// --implicit-check-not asserts none of the cuSPARSE library wrappers
// appear *anywhere* in the lowered IR — any of them would mean the
// sparsifier picked the libgen path instead of native codegen.
//
// RUN: mlir-opt %S/../reference/gcn.linalg-on-tensors.mlir \
// RUN:   --sparsifier="enable-runtime-library=false parallelization-strategy=dense-outer-loop gpu-num-threads=128 gpu-triple=nvptx64-nvidia-cuda gpu-chip=sm_89 gpu-features=+ptx80 gpu-format=fatbin" \
// RUN: | FileCheck %s \
// RUN:     --implicit-check-not=mgpuSpMM \
// RUN:     --implicit-check-not=mgpuSDDMM \
// RUN:     --implicit-check-not=mgpuCreateSparseEnv \
// RUN:     --implicit-check-not=mgpuCreateCsr \
// RUN:     --implicit-check-not=mgpuCreateDnTensor \
// RUN:     --implicit-check-not=cuSPARSE

// CHECK: gpu.binary @sparse_kernels
// CHECK: nvvm.target<chip = "sm_89"
// CHECK: gpu.launch_func
