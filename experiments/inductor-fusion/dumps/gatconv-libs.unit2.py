# AOT ID: ['2_inference']
from ctypes import c_void_p, c_long, c_int
import torch
import math
import random
import os
import tempfile
from math import inf, nan
from cmath import nanj
from torch._inductor.hooks import run_intermediate_hooks
from torch._inductor.utils import maybe_profile
from torch._inductor.codegen.memory_planning import _align as align
from torch import device, empty_strided
from torch._inductor.async_compile import AsyncCompile
from torch._inductor.select_algorithm import extern_kernels
from torch._C._dynamo.guards import copy_if_misaligned
import triton
import triton.language as tl
from torch._inductor.runtime.triton_heuristics import start_graph, end_graph
from torch._C import _cuda_getCurrentRawStream as get_raw_stream

aten = torch.ops.aten
inductor_ops = torch.ops.inductor
_quantized = torch.ops._quantized
assert_size_stride = torch._C._dynamo.guards.assert_size_stride
assert_alignment = torch._C._dynamo.guards.assert_alignment
empty_strided_cpu = torch._C._dynamo.guards._empty_strided_cpu
empty_strided_cpu_pinned = torch._C._dynamo.guards._empty_strided_cpu_pinned
empty_strided_cuda = torch._C._dynamo.guards._empty_strided_cuda
empty_strided_xpu = torch._C._dynamo.guards._empty_strided_xpu
empty_strided_mtia = torch._C._dynamo.guards._empty_strided_mtia
reinterpret_tensor = torch._C._dynamo.guards._reinterpret_tensor
alloc_from_pool = torch.ops.inductor._alloc_from_pool
async_compile = AsyncCompile()
empty_strided_p2p = torch._C._distributed_c10d._SymmetricMemory.empty_strided_p2p


# kernel path: /tmp/torchinductor_vscode/6m/c6mzsc3be6r4cbuotctl7qrg7mer35kin654tejmzmox6dtisusy.py
# Topologically Sorted Source Nodes: [arange, view, loop_index, full_edge_index, edge_index_i, new_zeros, view_1, index, edge_index_j, alpha_j, alpha_i, alpha, alpha_1, src_max], Original ATen: [aten.arange, aten.view, aten.repeat, aten.cat, aten.select, aten.new_zeros, aten.expand, aten.index_select, aten.add, aten.leaky_relu, aten.scatter_reduce]
# Source node to ATen node mapping:
#   alpha => add
#   alpha_1 => gt, mul, where
#   alpha_i => index_1
#   alpha_j => index
#   arange => iota
#   edge_index_i => select
#   edge_index_j => select_1
#   full_edge_index => cat
#   index => expand
#   loop_index => repeat
#   new_zeros => full_default
#   src_max => scatter_reduce
#   view => view
#   view_1 => view_1
# Graph fragment:
#   %iota : Tensor "i64[100][1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.iota.default](args = (100,), kwargs = {start: 0, step: 1, dtype: torch.int64, device: cuda:0, requires_grad: False})
#   %view : Tensor "i64[1, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.reshape.default](args = (%iota, [1, -1]), kwargs = {})
#   %repeat : Tensor "i64[2, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.repeat.default](args = (%view, [2, 1]), kwargs = {})
#   %cat : Tensor "i64[2, 596][596, 1]cuda:0"[num_users=4] = call_function[target=torch.ops.aten.cat.default](args = ([%arg0_1, %repeat], 1), kwargs = {})
#   %select : Tensor "i64[596][1]cuda:0"[num_users=5] = call_function[target=torch.ops.aten.select.int](args = (%cat, 0, 1), kwargs = {})
#   %full_default : Tensor "f32[100, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.full.default](args = ([100, 4], 0), kwargs = {dtype: torch.float32, layout: torch.strided, device: cuda:0, pin_memory: False})
#   %view_1 : Tensor "i64[596, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.reshape.default](args = (%select, [-1, 1]), kwargs = {})
#   %expand : Tensor "i64[596, 4][1, 0]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.expand.default](args = (%view_1, [596, 4]), kwargs = {})
#   %select_1 : Tensor "i64[596][1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.select.int](args = (%cat, 0, 0), kwargs = {})
#   %index : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.index.Tensor](args = (%arg1_1, [%select_1]), kwargs = {})
#   %index_1 : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.index.Tensor](args = (%arg2_1, [%select]), kwargs = {})
#   %add : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=3] = call_function[target=torch.ops.aten.add.Tensor](args = (%index, %index_1), kwargs = {})
#   %gt : Tensor "b8[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.gt.Scalar](args = (%add, 0), kwargs = {})
#   %mul : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%add, 0.2), kwargs = {})
#   %where : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.aten.where.self](args = (%gt, %add, %mul), kwargs = {})
#   %scatter_reduce : Tensor "f32[100, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.scatter_reduce.two](args = (%full_default, 0, %expand, %where, amax), kwargs = {include_self: False})
#   return %scatter_reduce
triton_poi_fused_add_arange_cat_expand_index_select_leaky_relu_new_zeros_repeat_scatter_reduce_select_view_0 = async_compile.triton('triton_poi_fused_add_arange_cat_expand_index_select_leaky_relu_new_zeros_repeat_scatter_reduce_select_view_0', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.pointwise(
    size_hints={'x': 512}, 
    filename=__file__,
    triton_meta={'signature': {'out_ptr0': '*fp32', 'xnumel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=46, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_poi_fused_add_arange_cat_expand_index_select_leaky_relu_new_zeros_repeat_scatter_reduce_select_view_0', 'mutated_arg_names': [], 'optimize_mem': True, 'no_x_dim': False, 'atomic_add_found': False, 'num_load': 0, 'num_store': 1, 'num_reduction': 0, 'autotune_hints': set(), 'tiling_scores': {'x': 3200}, 'backend_hash': '3FD01293DEFE1E301962659F5B82BF7E17A687A5569B171BBBFF36B97C970A90', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False},
    min_elem_per_thread=0
)
@triton.jit
def triton_poi_fused_add_arange_cat_expand_index_select_leaky_relu_new_zeros_repeat_scatter_reduce_select_view_0(out_ptr0, xnumel, XBLOCK : tl.constexpr):
    xnumel = 400
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:]
    xmask = xindex < xnumel
    x0 = xindex
    tmp0 = tl.full([1], 0.0, tl.float32)
    tl.store(out_ptr0 + (x0), tmp0, xmask)
''', device_str='cuda')


# kernel path: /tmp/torchinductor_vscode/sg/csguspznuxwkniz5ds7vj3vqxntsglw6oxdnh2ubwip6rfutprx6.py
# Topologically Sorted Source Nodes: [arange, view, loop_index, full_edge_index], Original ATen: [aten.arange, aten.view, aten.repeat, aten.cat]
# Source node to ATen node mapping:
#   arange => iota
#   full_edge_index => cat
#   loop_index => repeat
#   view => view
# Graph fragment:
#   %arg0_1 : Tensor "i64[2, 496][496, 1]cuda:0" = PlaceHolder[target=arg0_1]
#   %iota : Tensor "i64[100][1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.iota.default](args = (100,), kwargs = {start: 0, step: 1, dtype: torch.int64, device: cuda:0, requires_grad: False})
#   %view : Tensor "i64[1, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.reshape.default](args = (%iota, [1, -1]), kwargs = {})
#   %repeat : Tensor "i64[2, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.repeat.default](args = (%view, [2, 1]), kwargs = {})
#   %cat : Tensor "i64[2, 596][596, 1]cuda:0"[num_users=4] = call_function[target=torch.ops.aten.cat.default](args = ([%arg0_1, %repeat], 1), kwargs = {})
#   return %cat
triton_poi_fused_arange_cat_repeat_view_1 = async_compile.triton('triton_poi_fused_arange_cat_repeat_view_1', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.pointwise(
    size_hints={'x': 2048}, 
    filename=__file__,
    triton_meta={'signature': {'in_ptr0': '*i64', 'out_ptr0': '*i64', 'xnumel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=46, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_poi_fused_arange_cat_repeat_view_1', 'mutated_arg_names': [], 'optimize_mem': True, 'no_x_dim': False, 'atomic_add_found': False, 'num_load': 1, 'num_store': 1, 'num_reduction': 0, 'autotune_hints': set(), 'tiling_scores': {'x': 27008}, 'backend_hash': '3FD01293DEFE1E301962659F5B82BF7E17A687A5569B171BBBFF36B97C970A90', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False},
    min_elem_per_thread=0
)
@triton.jit
def triton_poi_fused_arange_cat_repeat_view_1(in_ptr0, out_ptr0, xnumel, XBLOCK : tl.constexpr):
    xnumel = 1192
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:]
    xmask = xindex < xnumel
    x0 = (xindex % 596)
    x1 = xindex // 596
    x2 = xindex
    tmp0 = x0
    tmp1 = tl.full([1], 0, tl.int64)
    tmp2 = tmp0 >= tmp1
    tmp3 = tl.full([1], 496, tl.int64)
    tmp4 = tmp0 < tmp3
    tmp5 = tl.load(in_ptr0 + (496*x1 + (x0)), tmp4 & xmask, other=0.0)
    tmp6 = tmp0 >= tmp3
    tmp7 = tl.full([1], 596, tl.int64)
    tmp8 = tmp0 < tmp7
    tmp9 = (-496) + x0
    tmp10 = tl.full(tmp9.shape, 0.0, tmp9.dtype)
    tmp11 = tl.where(tmp6, tmp9, tmp10)
    tmp12 = tl.where(tmp4, tmp5, tmp11)
    tl.store(out_ptr0 + (x2), tmp12, xmask)
''', device_str='cuda')


# kernel path: /tmp/torchinductor_vscode/jd/cjd5bzqj36yru5lnmhdvfcsiklc535aeg77gst2acafboh5qraec.py
# Topologically Sorted Source Nodes: [arange, view, loop_index, full_edge_index, edge_index_i, edge_index_j, alpha_j, alpha_i, alpha, alpha_1], Original ATen: [aten.arange, aten.view, aten.repeat, aten.cat, aten.select, aten.index_select, aten.add, aten.leaky_relu]
# Source node to ATen node mapping:
#   alpha => add
#   alpha_1 => gt, mul, where
#   alpha_i => index_1
#   alpha_j => index
#   arange => iota
#   edge_index_i => select
#   edge_index_j => select_1
#   full_edge_index => cat
#   loop_index => repeat
#   view => view
# Graph fragment:
#   %arg0_1 : Tensor "i64[2, 496][496, 1]cuda:0" = PlaceHolder[target=arg0_1]
#   %arg1_1 : Tensor "f32[100, 4][4, 1]cuda:0" = PlaceHolder[target=arg1_1]
#   %arg2_1 : Tensor "f32[100, 4][4, 1]cuda:0" = PlaceHolder[target=arg2_1]
#   %iota : Tensor "i64[100][1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.iota.default](args = (100,), kwargs = {start: 0, step: 1, dtype: torch.int64, device: cuda:0, requires_grad: False})
#   %view : Tensor "i64[1, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.reshape.default](args = (%iota, [1, -1]), kwargs = {})
#   %repeat : Tensor "i64[2, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.repeat.default](args = (%view, [2, 1]), kwargs = {})
#   %cat : Tensor "i64[2, 596][596, 1]cuda:0"[num_users=4] = call_function[target=torch.ops.aten.cat.default](args = ([%arg0_1, %repeat], 1), kwargs = {})
#   %select : Tensor "i64[596][1]cuda:0"[num_users=5] = call_function[target=torch.ops.aten.select.int](args = (%cat, 0, 1), kwargs = {})
#   %select_1 : Tensor "i64[596][1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.select.int](args = (%cat, 0, 0), kwargs = {})
#   %index : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.index.Tensor](args = (%arg1_1, [%select_1]), kwargs = {})
#   %index_1 : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.index.Tensor](args = (%arg2_1, [%select]), kwargs = {})
#   %add : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=3] = call_function[target=torch.ops.aten.add.Tensor](args = (%index, %index_1), kwargs = {})
#   %gt : Tensor "b8[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.gt.Scalar](args = (%add, 0), kwargs = {})
#   %mul : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%add, 0.2), kwargs = {})
#   %where : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.aten.where.self](args = (%gt, %add, %mul), kwargs = {})
#   return %where
triton_poi_fused_add_arange_cat_index_select_leaky_relu_repeat_select_view_2 = async_compile.triton('triton_poi_fused_add_arange_cat_index_select_leaky_relu_repeat_select_view_2', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.pointwise(
    size_hints={'x': 4096}, 
    filename=__file__,
    triton_meta={'signature': {'in_ptr0': '*i64', 'in_ptr1': '*fp32', 'in_ptr2': '*fp32', 'out_ptr0': '*fp32', 'xnumel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=46, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]], (2,): [['tt.divisibility', 16]], (3,): [['tt.divisibility', 16]], (4,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_poi_fused_add_arange_cat_index_select_leaky_relu_repeat_select_view_2', 'mutated_arg_names': [], 'optimize_mem': True, 'no_x_dim': False, 'atomic_add_found': False, 'num_load': 2, 'num_store': 1, 'num_reduction': 0, 'autotune_hints': set(), 'tiling_scores': {'x': 19072}, 'backend_hash': '3FD01293DEFE1E301962659F5B82BF7E17A687A5569B171BBBFF36B97C970A90', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False},
    min_elem_per_thread=0
)
@triton.jit
def triton_poi_fused_add_arange_cat_index_select_leaky_relu_repeat_select_view_2(in_ptr0, in_ptr1, in_ptr2, out_ptr0, xnumel, XBLOCK : tl.constexpr):
    xnumel = 2384
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:]
    xmask = xindex < xnumel
    x1 = xindex // 4
    x0 = (xindex % 4)
    x2 = xindex
    tmp0 = x1
    tmp1 = tl.full([1], 0, tl.int64)
    tmp2 = tmp0 >= tmp1
    tmp3 = tl.full([1], 496, tl.int64)
    tmp4 = tmp0 < tmp3
    tmp5 = tl.load(in_ptr0 + (x1), tmp4 & xmask, eviction_policy='evict_last', other=0.0)
    tmp6 = tmp0 >= tmp3
    tmp7 = tl.full([1], 596, tl.int64)
    tmp8 = tmp0 < tmp7
    tmp9 = (-496) + x1
    tmp10 = tl.full(tmp9.shape, 0.0, tmp9.dtype)
    tmp11 = tl.where(tmp6, tmp9, tmp10)
    tmp12 = tl.where(tmp4, tmp5, tmp11)
    tmp13 = tl.full([XBLOCK], 100, tl.int32)
    tmp14 = tmp12 + tmp13
    tmp15 = tmp12 < 0
    tmp16 = tl.where(tmp15, tmp14, tmp12)
    tl.device_assert(((0 <= tmp16) & (tmp16 < 100)) | ~(xmask), "index out of bounds: 0 <= tmp16 < 100")
    tmp18 = tl.load(in_ptr1 + (x0 + 4*tmp16), xmask)
    tmp19 = tl.load(in_ptr0 + (496 + (x1)), tmp4 & xmask, eviction_policy='evict_last', other=0.0)
    tmp20 = tl.where(tmp4, tmp19, tmp11)
    tmp21 = tmp20 + tmp13
    tmp22 = tmp20 < 0
    tmp23 = tl.where(tmp22, tmp21, tmp20)
    tl.device_assert(((0 <= tmp23) & (tmp23 < 100)) | ~(xmask), "index out of bounds: 0 <= tmp23 < 100")
    tmp25 = tl.load(in_ptr2 + (x0 + 4*tmp23), xmask)
    tmp26 = tmp18 + tmp25
    tmp27 = tl.full([1], 0.0, tl.float32)
    tmp28 = tmp26 > tmp27
    tmp29 = tl.full([1], 0.2, tl.float32)
    tmp30 = tmp26 * tmp29
    tmp31 = tl.where(tmp28, tmp26, tmp30)
    tl.store(out_ptr0 + (x2), tmp31, xmask)
''', device_str='cuda')


# kernel path: /tmp/torchinductor_vscode/nn/cnnbzomyziv4s7qxrokwtknsw3x7skn2apx3637yxxorsv7uoeo6.py
# Topologically Sorted Source Nodes: [arange, view, loop_index, full_edge_index, new_zeros_1, edge_index_i, view_2, index_1, index_select_2, out, out_1, scatter_add_], Original ATen: [aten.arange, aten.view, aten.repeat, aten.cat, aten.new_zeros, aten.select, aten.expand, aten.index_select, aten.sub, aten.exp, aten.scatter_add]
# Source node to ATen node mapping:
#   arange => iota
#   edge_index_i => select
#   full_edge_index => cat
#   index_1 => expand_1
#   index_select_2 => index_2
#   loop_index => repeat
#   new_zeros_1 => full_default_1
#   out => sub
#   out_1 => exp
#   scatter_add_ => scatter_add
#   view => view
#   view_2 => view_2
# Graph fragment:
#   %cat : Tensor "i64[2, 596][596, 1]cuda:0" = PlaceHolder[target=cat]
#   %where : Tensor "f32[596, 4][4, 1]cuda:0" = PlaceHolder[target=where]
#   %buf3 : Tensor  = PlaceHolder[target=buf3]
#   %scatter_add : Tensor "f32[100, 4][4, 1]cuda:0" = PlaceHolder[target=scatter_add]
#   %iota : Tensor "i64[100][1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.iota.default](args = (100,), kwargs = {start: 0, step: 1, dtype: torch.int64, device: cuda:0, requires_grad: False})
#   %view : Tensor "i64[1, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.reshape.default](args = (%iota, [1, -1]), kwargs = {})
#   %repeat : Tensor "i64[2, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.repeat.default](args = (%view, [2, 1]), kwargs = {})
#   %cat : Tensor "i64[2, 596][596, 1]cuda:0"[num_users=4] = call_function[target=torch.ops.aten.cat.default](args = ([%arg0_1, %repeat], 1), kwargs = {})
#   %full_default_1 : Tensor "f32[100, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.full.default](args = ([100, 4], 0), kwargs = {dtype: torch.float32, layout: torch.strided, device: cuda:0, pin_memory: False})
#   %select : Tensor "i64[596][1]cuda:0"[num_users=5] = call_function[target=torch.ops.aten.select.int](args = (%cat, 0, 1), kwargs = {})
#   %view_2 : Tensor "i64[596, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.reshape.default](args = (%select, [-1, 1]), kwargs = {})
#   %expand_1 : Tensor "i64[596, 4][1, 0]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.expand.default](args = (%view_2, [596, 4]), kwargs = {})
#   %index_2 : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.index.Tensor](args = (%scatter_reduce, [%select]), kwargs = {})
#   %sub : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.sub.Tensor](args = (%where, %index_2), kwargs = {})
#   %exp : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.aten.exp.default](args = (%sub,), kwargs = {})
#   %scatter_add : Tensor "f32[100, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.scatter_add.default](args = (%full_default_1, 0, %expand_1, %exp), kwargs = {})
#   return %buf5
triton_poi_fused_arange_cat_exp_expand_index_select_new_zeros_repeat_scatter_add_select_sub_view_3 = async_compile.triton('triton_poi_fused_arange_cat_exp_expand_index_select_new_zeros_repeat_scatter_add_select_sub_view_3', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.pointwise(
    size_hints={'x': 4096}, 
    filename=__file__,
    triton_meta={'signature': {'in_ptr0': '*i64', 'in_ptr1': '*fp32', 'in_ptr2': '*fp32', 'out_ptr0': '*fp32', 'xnumel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=46, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]], (2,): [['tt.divisibility', 16]], (3,): [['tt.divisibility', 16]], (4,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_poi_fused_arange_cat_exp_expand_index_select_new_zeros_repeat_scatter_add_select_sub_view_3', 'mutated_arg_names': ['out_ptr0'], 'optimize_mem': True, 'no_x_dim': False, 'atomic_add_found': True, 'num_load': 2, 'num_store': 1, 'num_reduction': 0, 'autotune_hints': set(), 'tiling_scores': {'x': 9536}, 'backend_hash': '3FD01293DEFE1E301962659F5B82BF7E17A687A5569B171BBBFF36B97C970A90', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False},
    min_elem_per_thread=0
)
@triton.jit
def triton_poi_fused_arange_cat_exp_expand_index_select_new_zeros_repeat_scatter_add_select_sub_view_3(in_ptr0, in_ptr1, in_ptr2, out_ptr0, xnumel, XBLOCK : tl.constexpr):
    xnumel = 2384
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:]
    xmask = xindex < xnumel
    x1 = xindex // 4
    x2 = xindex
    x0 = (xindex % 4)
    tmp0 = tl.load(in_ptr0 + (596 + x1), xmask, eviction_policy='evict_last')
    tmp2 = tl.load(in_ptr1 + (x2), xmask)
    tl.device_assert(((0 <= tmp0) & (tmp0 < 100)) | ~(xmask), "index out of bounds: 0 <= tmp0 < 100")
    tmp3 = tl.full([XBLOCK], 100, tl.int32)
    tmp4 = tmp0 + tmp3
    tmp5 = tmp0 < 0
    tmp6 = tl.where(tmp5, tmp4, tmp0)
    tl.device_assert(((0 <= tmp6) & (tmp6 < 100)) | ~(xmask), "index out of bounds: 0 <= tmp6 < 100")
    tmp8 = tl.load(in_ptr2 + (x0 + 4*tmp6), xmask)
    tmp9 = tmp2 - tmp8
    tmp10 = libdevice.exp(tmp9)
    tl.atomic_add(out_ptr0 + (x0 + 4*tmp0), tmp10, xmask, sem='relaxed')
''', device_str='cuda')


# kernel path: /tmp/torchinductor_vscode/ok/cokh76oaygtrsl4zfbdhiat7lnufnoqcd32apv2pnzuzfc4jkdqz.py
# Topologically Sorted Source Nodes: [new_zeros_2, arange, view, loop_index, full_edge_index, edge_index_i_1, view_3, index_2, edge_index_i, index_select_2, out, out_1, out_sum, out_sum_1, alpha_2, unsqueeze, edge_index_j_1, x_j, out_2, out_3], Original ATen: [aten.new_zeros, aten.arange, aten.view, aten.repeat, aten.cat, aten.select, aten.expand, aten.index_select, aten.sub, aten.exp, aten.add, aten.div, aten.unsqueeze, aten.mul, aten.scatter_add]
# Source node to ATen node mapping:
#   alpha_2 => div
#   arange => iota
#   edge_index_i => select
#   edge_index_i_1 => select_2
#   edge_index_j_1 => select_3
#   full_edge_index => cat
#   index_2 => expand_2
#   index_select_2 => index_2
#   loop_index => repeat
#   new_zeros_2 => full_default_2
#   out => sub
#   out_1 => exp
#   out_2 => mul_1
#   out_3 => scatter_add_1
#   out_sum => add_1
#   out_sum_1 => index_3
#   unsqueeze => unsqueeze
#   view => view
#   view_3 => view_3
#   x_j => index_4
# Graph fragment:
#   %full_default_2 : Tensor "f32[100, 4, 8][32, 8, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.full.default](args = ([100, 4, 8], 0), kwargs = {dtype: torch.float32, layout: torch.strided, device: cuda:0, pin_memory: False})
#   %iota : Tensor "i64[100][1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.iota.default](args = (100,), kwargs = {start: 0, step: 1, dtype: torch.int64, device: cuda:0, requires_grad: False})
#   %view : Tensor "i64[1, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.reshape.default](args = (%iota, [1, -1]), kwargs = {})
#   %repeat : Tensor "i64[2, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.repeat.default](args = (%view, [2, 1]), kwargs = {})
#   %cat : Tensor "i64[2, 596][596, 1]cuda:0"[num_users=4] = call_function[target=torch.ops.aten.cat.default](args = ([%arg0_1, %repeat], 1), kwargs = {})
#   %select_2 : Tensor "i64[596][1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.select.int](args = (%cat, 0, 1), kwargs = {})
#   %view_3 : Tensor "i64[596, 1, 1][1, 1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.reshape.default](args = (%select_2, [-1, 1, 1]), kwargs = {})
#   %expand_2 : Tensor "i64[596, 4, 8][1, 0, 0]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.expand.default](args = (%view_3, [596, 4, 8]), kwargs = {})
#   %select : Tensor "i64[596][1]cuda:0"[num_users=5] = call_function[target=torch.ops.aten.select.int](args = (%cat, 0, 1), kwargs = {})
#   %index_2 : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.index.Tensor](args = (%scatter_reduce, [%select]), kwargs = {})
#   %sub : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.sub.Tensor](args = (%where, %index_2), kwargs = {})
#   %exp : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.aten.exp.default](args = (%sub,), kwargs = {})
#   %add_1 : Tensor "f32[100, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%scatter_add, 1e-16), kwargs = {})
#   %index_3 : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.index.Tensor](args = (%add_1, [%select]), kwargs = {})
#   %div : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.div.Tensor](args = (%exp, %index_3), kwargs = {})
#   %unsqueeze : Tensor "f32[596, 4, 1][4, 1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.unsqueeze.default](args = (%div, -1), kwargs = {})
#   %select_3 : Tensor "i64[596][1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.select.int](args = (%cat, 0, 0), kwargs = {})
#   %index_4 : Tensor "f32[596, 4, 8][32, 8, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.index.Tensor](args = (%arg3_1, [%select_3]), kwargs = {})
#   %mul_1 : Tensor "f32[596, 4, 8][32, 8, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%unsqueeze, %index_4), kwargs = {})
#   %scatter_add_1 : Tensor "f32[100, 4, 8][32, 8, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.scatter_add.default](args = (%full_default_2, 0, %expand_2, %mul_1), kwargs = {})
#   return %scatter_add_1
triton_poi_fused_add_arange_cat_div_exp_expand_index_select_mul_new_zeros_repeat_scatter_add_select_sub_unsqueeze_view_4 = async_compile.triton('triton_poi_fused_add_arange_cat_div_exp_expand_index_select_mul_new_zeros_repeat_scatter_add_select_sub_unsqueeze_view_4', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.pointwise(
    size_hints={'x': 4096}, 
    filename=__file__,
    triton_meta={'signature': {'out_ptr0': '*fp32', 'xnumel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=46, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_poi_fused_add_arange_cat_div_exp_expand_index_select_mul_new_zeros_repeat_scatter_add_select_sub_unsqueeze_view_4', 'mutated_arg_names': [], 'optimize_mem': True, 'no_x_dim': False, 'atomic_add_found': False, 'num_load': 0, 'num_store': 1, 'num_reduction': 0, 'autotune_hints': set(), 'tiling_scores': {'x': 25600}, 'backend_hash': '3FD01293DEFE1E301962659F5B82BF7E17A687A5569B171BBBFF36B97C970A90', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False},
    min_elem_per_thread=0
)
@triton.jit
def triton_poi_fused_add_arange_cat_div_exp_expand_index_select_mul_new_zeros_repeat_scatter_add_select_sub_unsqueeze_view_4(out_ptr0, xnumel, XBLOCK : tl.constexpr):
    xnumel = 3200
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:]
    xmask = xindex < xnumel
    x0 = xindex
    tmp0 = tl.full([1], 0.0, tl.float32)
    tl.store(out_ptr0 + (x0), tmp0, xmask)
''', device_str='cuda')


# kernel path: /tmp/torchinductor_vscode/qi/cqisfqvp36cpp6u4ym6ydrhfnuqzenkwgplbiqimcifr26wwsyi4.py
# Topologically Sorted Source Nodes: [new_zeros_2, arange, view, loop_index, full_edge_index, edge_index_i_1, view_3, index_2, edge_index_i, index_select_2, out, out_1, out_sum, out_sum_1, alpha_2, unsqueeze, edge_index_j_1, x_j, out_2, out_3], Original ATen: [aten.new_zeros, aten.arange, aten.view, aten.repeat, aten.cat, aten.select, aten.expand, aten.index_select, aten.sub, aten.exp, aten.add, aten.div, aten.unsqueeze, aten.mul, aten.scatter_add]
# Source node to ATen node mapping:
#   alpha_2 => div
#   arange => iota
#   edge_index_i => select
#   edge_index_i_1 => select_2
#   edge_index_j_1 => select_3
#   full_edge_index => cat
#   index_2 => expand_2
#   index_select_2 => index_2
#   loop_index => repeat
#   new_zeros_2 => full_default_2
#   out => sub
#   out_1 => exp
#   out_2 => mul_1
#   out_3 => scatter_add_1
#   out_sum => add_1
#   out_sum_1 => index_3
#   unsqueeze => unsqueeze
#   view => view
#   view_3 => view_3
#   x_j => index_4
# Graph fragment:
#   %cat : Tensor "i64[2, 596][596, 1]cuda:0" = PlaceHolder[target=cat]
#   %where : Tensor "f32[596, 4][4, 1]cuda:0" = PlaceHolder[target=where]
#   %buf3 : Tensor  = PlaceHolder[target=buf3]
#   %buf5 : Tensor "f32[100, 4][4, 1]cuda:0" = PlaceHolder[target=buf5]
#   %arg3_1 : Tensor "f32[100, 4, 8][32, 8, 1]cuda:0" = PlaceHolder[target=arg3_1]
#   %scatter_add_1 : Tensor "f32[100, 4, 8][32, 8, 1]cuda:0" = PlaceHolder[target=scatter_add_1]
#   %full_default_2 : Tensor "f32[100, 4, 8][32, 8, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.full.default](args = ([100, 4, 8], 0), kwargs = {dtype: torch.float32, layout: torch.strided, device: cuda:0, pin_memory: False})
#   %iota : Tensor "i64[100][1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.iota.default](args = (100,), kwargs = {start: 0, step: 1, dtype: torch.int64, device: cuda:0, requires_grad: False})
#   %view : Tensor "i64[1, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.reshape.default](args = (%iota, [1, -1]), kwargs = {})
#   %repeat : Tensor "i64[2, 100][100, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.repeat.default](args = (%view, [2, 1]), kwargs = {})
#   %cat : Tensor "i64[2, 596][596, 1]cuda:0"[num_users=4] = call_function[target=torch.ops.aten.cat.default](args = ([%arg0_1, %repeat], 1), kwargs = {})
#   %select_2 : Tensor "i64[596][1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.select.int](args = (%cat, 0, 1), kwargs = {})
#   %view_3 : Tensor "i64[596, 1, 1][1, 1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.reshape.default](args = (%select_2, [-1, 1, 1]), kwargs = {})
#   %expand_2 : Tensor "i64[596, 4, 8][1, 0, 0]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.expand.default](args = (%view_3, [596, 4, 8]), kwargs = {})
#   %select : Tensor "i64[596][1]cuda:0"[num_users=5] = call_function[target=torch.ops.aten.select.int](args = (%cat, 0, 1), kwargs = {})
#   %index_2 : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.index.Tensor](args = (%scatter_reduce, [%select]), kwargs = {})
#   %sub : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.sub.Tensor](args = (%where, %index_2), kwargs = {})
#   %exp : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.aten.exp.default](args = (%sub,), kwargs = {})
#   %add_1 : Tensor "f32[100, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%scatter_add, 1e-16), kwargs = {})
#   %index_3 : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.index.Tensor](args = (%add_1, [%select]), kwargs = {})
#   %div : Tensor "f32[596, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.div.Tensor](args = (%exp, %index_3), kwargs = {})
#   %unsqueeze : Tensor "f32[596, 4, 1][4, 1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.unsqueeze.default](args = (%div, -1), kwargs = {})
#   %select_3 : Tensor "i64[596][1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.select.int](args = (%cat, 0, 0), kwargs = {})
#   %index_4 : Tensor "f32[596, 4, 8][32, 8, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.index.Tensor](args = (%arg3_1, [%select_3]), kwargs = {})
#   %mul_1 : Tensor "f32[596, 4, 8][32, 8, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%unsqueeze, %index_4), kwargs = {})
#   %scatter_add_1 : Tensor "f32[100, 4, 8][32, 8, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.scatter_add.default](args = (%full_default_2, 0, %expand_2, %mul_1), kwargs = {})
#   return %buf7
triton_poi_fused_add_arange_cat_div_exp_expand_index_select_mul_new_zeros_repeat_scatter_add_select_sub_unsqueeze_view_5 = async_compile.triton('triton_poi_fused_add_arange_cat_div_exp_expand_index_select_mul_new_zeros_repeat_scatter_add_select_sub_unsqueeze_view_5', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.pointwise(
    size_hints={'z': 1024, 'y': 4, 'x': 8}, 
    filename=__file__,
    triton_meta={'signature': {'in_ptr0': '*i64', 'in_ptr1': '*fp32', 'in_ptr2': '*fp32', 'in_ptr3': '*fp32', 'in_ptr4': '*fp32', 'out_ptr0': '*fp32', 'znumel': 'i32', 'ynumel': 'i32', 'xnumel': 'i32', 'ZBLOCK': 'constexpr', 'YBLOCK': 'constexpr', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=46, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]], (2,): [['tt.divisibility', 16]], (3,): [['tt.divisibility', 16]], (4,): [['tt.divisibility', 16]], (5,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid3D', 'kernel_name': 'triton_poi_fused_add_arange_cat_div_exp_expand_index_select_mul_new_zeros_repeat_scatter_add_select_sub_unsqueeze_view_5', 'mutated_arg_names': ['out_ptr0'], 'optimize_mem': True, 'no_x_dim': False, 'atomic_add_found': True, 'num_load': 3, 'num_store': 1, 'num_reduction': 0, 'autotune_hints': set(), 'tiling_scores': {'z': 9536, 'y': 4768, 'x': 0}, 'backend_hash': '3FD01293DEFE1E301962659F5B82BF7E17A687A5569B171BBBFF36B97C970A90', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False},
    min_elem_per_thread=0
)
@triton.jit
def triton_poi_fused_add_arange_cat_div_exp_expand_index_select_mul_new_zeros_repeat_scatter_add_select_sub_unsqueeze_view_5(in_ptr0, in_ptr1, in_ptr2, in_ptr3, in_ptr4, out_ptr0, znumel, ynumel, xnumel, ZBLOCK : tl.constexpr, YBLOCK : tl.constexpr, XBLOCK : tl.constexpr):
    znumel = 596
    ynumel = 4
    xnumel = 8
    zoffset = tl.program_id(2) * ZBLOCK
    zindex = zoffset + tl.arange(0, ZBLOCK)[:, None, None]
    zmask = zindex < znumel
    yoffset = tl.program_id(1) * YBLOCK
    yindex = yoffset + tl.arange(0, YBLOCK)[None, :, None]
    ymask = yindex < ynumel
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[None, None, :]
    xmask = xindex < xnumel
    z0 = zindex
    y1 = yindex
    x2 = xindex
    tmp0 = tl.load(in_ptr0 + (596 + z0), zmask, eviction_policy='evict_last')
    tmp2 = tl.load(in_ptr1 + (y1 + 4*z0), ymask & zmask, eviction_policy='evict_last')
    tmp15 = tl.load(in_ptr0 + (z0), zmask, eviction_policy='evict_last')
    tl.device_assert(((0 <= tmp0) & (tmp0 < 100)) | ~(zmask), "index out of bounds: 0 <= tmp0 < 100")
    tmp3 = tl.full([1, 1, 1], 100, tl.int32)
    tmp4 = tmp0 + tmp3
    tmp5 = tmp0 < 0
    tmp6 = tl.where(tmp5, tmp4, tmp0)
    tl.device_assert(((0 <= tmp6) & (tmp6 < 100)) | ~(zmask), "index out of bounds: 0 <= tmp6 < 100")
    tmp8 = tl.load(in_ptr2 + (y1 + 4*tmp6), ymask & zmask)
    tmp9 = tmp2 - tmp8
    tmp10 = libdevice.exp(tmp9)
    tmp11 = tl.load(in_ptr3 + (y1 + 4*tmp6), ymask & zmask)
    tmp12 = tl.full([1, 1, 1], 1e-16, tl.float32)
    tmp13 = tmp11 + tmp12
    tmp14 = (tmp10 / tmp13)
    tmp16 = tmp15 + tmp3
    tmp17 = tmp15 < 0
    tmp18 = tl.where(tmp17, tmp16, tmp15)
    tl.device_assert(((0 <= tmp18) & (tmp18 < 100)) | ~(zmask), "index out of bounds: 0 <= tmp18 < 100")
    tmp20 = tl.load(in_ptr4 + (x2 + 8*y1 + 32*tmp18), xmask & ymask & zmask)
    tmp21 = tmp14 * tmp20
    tl.atomic_add(out_ptr0 + (tl.broadcast_to(x2 + 8*y1 + 32*tmp0, [ZBLOCK, YBLOCK, XBLOCK])), tmp21, xmask & ymask & zmask, sem='relaxed')
''', device_str='cuda')


# kernel path: /tmp/torchinductor_vscode/5e/c5emmusnmbkazuuyg6absqyyvkky2lot5nt3y6ljybozc67qane7.py
# Topologically Sorted Source Nodes: [out_5], Original ATen: [aten.view, aten.add]
# Source node to ATen node mapping:
#   out_5 => add_2, view_5
# Graph fragment:
#   %buf7 : Tensor "f32[100, 4, 8][32, 8, 1]cuda:0" = PlaceHolder[target=buf7]
#   %arg4_1 : Tensor "f32[32][1]cuda:0" = PlaceHolder[target=arg4_1]
#   %view_5 : Tensor "f32[100, 32][32, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.reshape.default](args = (%scatter_add_1, [-1, 32]), kwargs = {})
#   %add_2 : Tensor "f32[100, 32][32, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%view_5, %arg4_1), kwargs = {})
#   return %add_2
triton_poi_fused_add_view_6 = async_compile.triton('triton_poi_fused_add_view_6', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.pointwise(
    size_hints={'x': 4096}, 
    filename=__file__,
    triton_meta={'signature': {'in_ptr0': '*fp32', 'in_ptr1': '*fp32', 'out_ptr0': '*fp32', 'xnumel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=46, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]], (2,): [['tt.divisibility', 16]], (3,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_poi_fused_add_view_6', 'mutated_arg_names': [], 'optimize_mem': True, 'no_x_dim': False, 'atomic_add_found': False, 'num_load': 2, 'num_store': 1, 'num_reduction': 0, 'autotune_hints': set(), 'tiling_scores': {'x': 25728}, 'backend_hash': '3FD01293DEFE1E301962659F5B82BF7E17A687A5569B171BBBFF36B97C970A90', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False},
    min_elem_per_thread=0
)
@triton.jit
def triton_poi_fused_add_view_6(in_ptr0, in_ptr1, out_ptr0, xnumel, XBLOCK : tl.constexpr):
    xnumel = 3200
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:]
    xmask = xindex < xnumel
    x2 = xindex
    x0 = (xindex % 32)
    tmp0 = tl.load(in_ptr0 + (x2), xmask)
    tmp1 = tl.load(in_ptr1 + (x0), xmask, eviction_policy='evict_last')
    tmp2 = tmp0 + tmp1
    tl.store(out_ptr0 + (x2), tmp2, xmask)
''', device_str='cuda')


async_compile.wait(globals())
del async_compile

class Runner:
    def __init__(self, partitions):
        self.partitions = partitions

    def recursively_apply_fns(self, fns):
        new_callables = []
        for fn, c in zip(fns, self.partitions):
            new_callables.append(fn(c))
        self.partitions = new_callables

    def call(self, args):
        arg0_1, arg1_1, arg2_1, arg3_1, arg4_1 = args
        args.clear()
        with torch.cuda._DeviceGuard(0):
            torch.cuda.set_device(0)
            buf0 = empty_strided_cuda((100, 4), (4, 1), torch.float32)
            # Topologically Sorted Source Nodes: [arange, view, loop_index, full_edge_index, edge_index_i, new_zeros, view_1, index, edge_index_j, alpha_j, alpha_i, alpha, alpha_1, src_max], Original ATen: [aten.arange, aten.view, aten.repeat, aten.cat, aten.select, aten.new_zeros, aten.expand, aten.index_select, aten.add, aten.leaky_relu, aten.scatter_reduce]
            raw_stream0 = get_raw_stream(0)
            triton_poi_fused_add_arange_cat_expand_index_select_leaky_relu_new_zeros_repeat_scatter_reduce_select_view_0.run(buf0, 400, stream=raw_stream0)
            assert_size_stride(arg0_1, (2, 496), (496, 1), 'input')
            arg0_1 = copy_if_misaligned(arg0_1)
            buf1 = empty_strided_cuda((2, 596), (596, 1), torch.int64)
            # Topologically Sorted Source Nodes: [arange, view, loop_index, full_edge_index], Original ATen: [aten.arange, aten.view, aten.repeat, aten.cat]
            raw_stream0 = get_raw_stream(0)
            triton_poi_fused_arange_cat_repeat_view_1.run(arg0_1, buf1, 1192, stream=raw_stream0)
            assert_size_stride(arg1_1, (100, 4), (4, 1), 'input')
            assert_size_stride(arg2_1, (100, 4), (4, 1), 'input')
            arg1_1 = copy_if_misaligned(arg1_1)
            arg2_1 = copy_if_misaligned(arg2_1)
            buf2 = empty_strided_cuda((596, 4), (4, 1), torch.float32)
            # Topologically Sorted Source Nodes: [arange, view, loop_index, full_edge_index, edge_index_i, edge_index_j, alpha_j, alpha_i, alpha, alpha_1], Original ATen: [aten.arange, aten.view, aten.repeat, aten.cat, aten.select, aten.index_select, aten.add, aten.leaky_relu]
            raw_stream0 = get_raw_stream(0)
            triton_poi_fused_add_arange_cat_index_select_leaky_relu_repeat_select_view_2.run(arg0_1, arg1_1, arg2_1, buf2, 2384, stream=raw_stream0)
            del arg0_1
            del arg1_1
            del arg2_1
            aten.scatter_reduce_.two(buf0,0,reinterpret_tensor(buf1, (596, 4), (1, 0), 596),buf2, reduce='amax', include_self=False)
            buf4 = empty_strided_cuda((100, 4), (4, 1), torch.float32)
            # Topologically Sorted Source Nodes: [arange, view, loop_index, full_edge_index, new_zeros_1, edge_index_i, view_2, index_1, index_select_2, out, out_1, scatter_add_], Original ATen: [aten.arange, aten.view, aten.repeat, aten.cat, aten.new_zeros, aten.select, aten.expand, aten.index_select, aten.sub, aten.exp, aten.scatter_add]
            raw_stream0 = get_raw_stream(0)
            triton_poi_fused_add_arange_cat_expand_index_select_leaky_relu_new_zeros_repeat_scatter_reduce_select_view_0.run(buf4, 400, stream=raw_stream0)
            # Topologically Sorted Source Nodes: [arange, view, loop_index, full_edge_index, new_zeros_1, edge_index_i, view_2, index_1, index_select_2, out, out_1, scatter_add_], Original ATen: [aten.arange, aten.view, aten.repeat, aten.cat, aten.new_zeros, aten.select, aten.expand, aten.index_select, aten.sub, aten.exp, aten.scatter_add]
            raw_stream0 = get_raw_stream(0)
            triton_poi_fused_arange_cat_exp_expand_index_select_new_zeros_repeat_scatter_add_select_sub_view_3.run(buf1, buf2, buf0, buf4, 2384, stream=raw_stream0)
            buf6 = empty_strided_cuda((100, 4, 8), (32, 8, 1), torch.float32)
            # Topologically Sorted Source Nodes: [new_zeros_2, arange, view, loop_index, full_edge_index, edge_index_i_1, view_3, index_2, edge_index_i, index_select_2, out, out_1, out_sum, out_sum_1, alpha_2, unsqueeze, edge_index_j_1, x_j, out_2, out_3], Original ATen: [aten.new_zeros, aten.arange, aten.view, aten.repeat, aten.cat, aten.select, aten.expand, aten.index_select, aten.sub, aten.exp, aten.add, aten.div, aten.unsqueeze, aten.mul, aten.scatter_add]
            raw_stream0 = get_raw_stream(0)
            triton_poi_fused_add_arange_cat_div_exp_expand_index_select_mul_new_zeros_repeat_scatter_add_select_sub_unsqueeze_view_4.run(buf6, 3200, stream=raw_stream0)
            assert_size_stride(arg3_1, (100, 4, 8), (32, 8, 1), 'input')
            arg3_1 = copy_if_misaligned(arg3_1)
            # Topologically Sorted Source Nodes: [new_zeros_2, arange, view, loop_index, full_edge_index, edge_index_i_1, view_3, index_2, edge_index_i, index_select_2, out, out_1, out_sum, out_sum_1, alpha_2, unsqueeze, edge_index_j_1, x_j, out_2, out_3], Original ATen: [aten.new_zeros, aten.arange, aten.view, aten.repeat, aten.cat, aten.select, aten.expand, aten.index_select, aten.sub, aten.exp, aten.add, aten.div, aten.unsqueeze, aten.mul, aten.scatter_add]
            raw_stream0 = get_raw_stream(0)
            triton_poi_fused_add_arange_cat_div_exp_expand_index_select_mul_new_zeros_repeat_scatter_add_select_sub_unsqueeze_view_5.run(buf1, buf2, buf0, buf4, arg3_1, buf6, 596, 4, 8, stream=raw_stream0)
            del arg3_1
            del buf0
            del buf1
            del buf2
            del buf4
            assert_size_stride(arg4_1, (32, ), (1, ), 'input')
            buf8 = empty_strided_cuda((100, 32), (32, 1), torch.float32)
            # Topologically Sorted Source Nodes: [out_5], Original ATen: [aten.view, aten.add]
            raw_stream0 = get_raw_stream(0)
            triton_poi_fused_add_view_6.run(buf6, arg4_1, buf8, 3200, stream=raw_stream0)
            del arg4_1
            del buf6
        return (buf8, )

runner = Runner(partitions=[])
call = runner.call
recursively_apply_fns = runner.recursively_apply_fns


def get_args():
    from torch._dynamo.testing import rand_strided
    arg0_1 = rand_strided((2, 496), (496, 1), device='cuda:0', dtype=torch.int64)
    arg1_1 = rand_strided((100, 4), (4, 1), device='cuda:0', dtype=torch.float32)
    arg2_1 = rand_strided((100, 4), (4, 1), device='cuda:0', dtype=torch.float32)
    arg3_1 = rand_strided((100, 4, 8), (32, 8, 1), device='cuda:0', dtype=torch.float32)
    arg4_1 = rand_strided((32, ), (1, ), device='cuda:0', dtype=torch.float32)
    return [arg0_1, arg1_1, arg2_1, arg3_1, arg4_1]


def benchmark_compiled_module(args, times=10, repeat=10):
    from torch._inductor.utils import print_performance
    fn = lambda: call(list(args))
    return print_performance(fn, times=times, repeat=repeat, device='cuda')


if __name__ == "__main__":
    from torch._inductor.wrapper_benchmark import compiled_module_main
    args = get_args()
    compiled_module_main('None', lambda times, repeat: benchmark_compiled_module(args, times=times, repeat=repeat))
