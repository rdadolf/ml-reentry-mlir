# AOT ID: ['0_inference']
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


# kernel path: /tmp/torchinductor_vscode/r2/cr25kaw42pzmq3mheo7nd246gwazwazjnjz26cgrtwkjhnudkxaw.py
# Topologically Sorted Source Nodes: [x_src, mul, alpha_src, mul_1, alpha_dst], Original ATen: [aten.view, aten.mul, aten.sum]
# Source node to ATen node mapping:
#   alpha_dst => sum_2
#   alpha_src => sum_1
#   mul => mul
#   mul_1 => mul_1
#   x_src => view
# Graph fragment:
#   %mm : Tensor "f32[100, 32][32, 1]cuda:0" = PlaceHolder[target=mm]
#   %arg2_1 : Tensor "f32[1, 4, 8][32, 8, 1]cuda:0" = PlaceHolder[target=arg2_1]
#   %arg3_1 : Tensor "f32[1, 4, 8][32, 8, 1]cuda:0" = PlaceHolder[target=arg3_1]
#   %view : Tensor "f32[100, 4, 8][32, 8, 1]cuda:0"[num_users=3] = call_function[target=torch.ops.aten.reshape.default](args = (%mm, [-1, 4, 8]), kwargs = {})
#   %mul : Tensor "f32[100, 4, 8][32, 8, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%view, %arg2_1), kwargs = {})
#   %sum_1 : Tensor "f32[100, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.sum.dim_IntList](args = (%mul, [-1]), kwargs = {})
#   %mul_1 : Tensor "f32[100, 4, 8][32, 8, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%view, %arg3_1), kwargs = {})
#   %sum_2 : Tensor "f32[100, 4][4, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.sum.dim_IntList](args = (%mul_1, [-1]), kwargs = {})
#   return %sum_1,%sum_2
triton_per_fused_mul_sum_view_0 = async_compile.triton('triton_per_fused_mul_sum_view_0', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.persistent_reduction(
    size_hints={'x': 512, 'r0_': 8},
    reduction_hint=ReductionHint.INNER,
    filename=__file__,
    triton_meta={'signature': {'in_ptr0': '*fp32', 'in_ptr1': '*fp32', 'in_ptr2': '*fp32', 'out_ptr0': '*fp32', 'out_ptr1': '*fp32', 'xnumel': 'i32', 'r0_numel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=46, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]], (2,): [['tt.divisibility', 16]], (3,): [['tt.divisibility', 16]], (4,): [['tt.divisibility', 16]], (5,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_per_fused_mul_sum_view_0', 'mutated_arg_names': [], 'optimize_mem': True, 'no_x_dim': None, 'atomic_add_found': False, 'num_load': 3, 'num_store': 2, 'num_reduction': 2, 'autotune_hints': set(), 'tiling_scores': {'x': 6400, 'r0_': 13056}, 'backend_hash': '3FD01293DEFE1E301962659F5B82BF7E17A687A5569B171BBBFF36B97C970A90', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False}
)
@triton.jit
def triton_per_fused_mul_sum_view_0(in_ptr0, in_ptr1, in_ptr2, out_ptr0, out_ptr1, xnumel, r0_numel, XBLOCK : tl.constexpr):
    xnumel = 400
    r0_numel = 8
    R0_BLOCK: tl.constexpr = 8
    rnumel = r0_numel
    RBLOCK: tl.constexpr = R0_BLOCK
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:, None]
    xmask = xindex < xnumel
    r0_index = tl.arange(0, R0_BLOCK)[None, :]
    r0_offset = 0
    r0_mask = r0_index < r0_numel
    roffset = r0_offset
    rindex = r0_index
    r0_2 = r0_index
    x3 = xindex
    x0 = (xindex % 4)
    tmp0 = tl.load(in_ptr0 + (r0_2 + 8*x3), r0_mask & xmask, other=0.0)
    tmp1 = tl.load(in_ptr1 + (r0_2 + 8*x0), r0_mask & xmask, eviction_policy='evict_last', other=0.0)
    tmp7 = tl.load(in_ptr2 + (r0_2 + 8*x0), r0_mask & xmask, eviction_policy='evict_last', other=0.0)
    tmp2 = tmp0 * tmp1
    tmp3 = tl.broadcast_to(tmp2, [XBLOCK, R0_BLOCK])
    tmp5 = tl.where(r0_mask & xmask, tmp3, 0)
    tmp6 = tl.sum(tmp5, 1)[:, None].to(tl.float32)
    tmp8 = tmp0 * tmp7
    tmp9 = tl.broadcast_to(tmp8, [XBLOCK, R0_BLOCK])
    tmp11 = tl.where(r0_mask & xmask, tmp9, 0)
    tmp12 = tl.sum(tmp11, 1)[:, None].to(tl.float32)
    tl.store(out_ptr0 + (x3), tmp6, xmask)
    tl.store(out_ptr1 + (x3), tmp12, xmask)
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
        arg0_1, arg1_1, arg2_1, arg3_1 = args
        args.clear()
        assert_size_stride(arg0_1, (100, 16), (16, 1), 'input')
        assert_size_stride(arg1_1, (32, 16), (16, 1), 'input')
        with torch.cuda._DeviceGuard(0):
            torch.cuda.set_device(0)
            arg0_1 = copy_if_misaligned(arg0_1)
            buf0 = empty_strided_cuda((100, 32), (32, 1), torch.float32)
            # Topologically Sorted Source Nodes: [linear], Original ATen: [aten.t, aten.mm]
            extern_kernels.mm(arg0_1, reinterpret_tensor(arg1_1, (16, 32), (1, 16), 0), out=buf0)
            del arg0_1
            del arg1_1
            assert_size_stride(arg2_1, (1, 4, 8), (32, 8, 1), 'input')
            assert_size_stride(arg3_1, (1, 4, 8), (32, 8, 1), 'input')
            buf1 = empty_strided_cuda((100, 4), (4, 1), torch.float32)
            buf2 = empty_strided_cuda((100, 4), (4, 1), torch.float32)
            # Topologically Sorted Source Nodes: [x_src, mul, alpha_src, mul_1, alpha_dst], Original ATen: [aten.view, aten.mul, aten.sum]
            raw_stream0 = get_raw_stream(0)
            triton_per_fused_mul_sum_view_0.run(buf0, arg2_1, arg3_1, buf1, buf2, 400, 8, stream=raw_stream0)
            del arg2_1
            del arg3_1
        return (reinterpret_tensor(buf0, (100, 4, 8), (32, 8, 1), 0), buf1, buf2, )

runner = Runner(partitions=[])
call = runner.call
recursively_apply_fns = runner.recursively_apply_fns


def get_args():
    from torch._dynamo.testing import rand_strided
    arg0_1 = rand_strided((100, 16), (16, 1), device='cuda:0', dtype=torch.float32)
    arg1_1 = rand_strided((32, 16), (16, 1), device='cuda:0', dtype=torch.float32)
    arg2_1 = rand_strided((1, 4, 8), (32, 8, 1), device='cuda:0', dtype=torch.float32)
    arg3_1 = rand_strided((1, 4, 8), (32, 8, 1), device='cuda:0', dtype=torch.float32)
    return [arg0_1, arg1_1, arg2_1, arg3_1]


def benchmark_compiled_module(args, times=10, repeat=10):
    from torch._inductor.utils import print_performance
    fn = lambda: call(list(args))
    return print_performance(fn, times=times, repeat=repeat, device='cuda')


if __name__ == "__main__":
    from torch._inductor.wrapper_benchmark import compiled_module_main
    args = get_args()
    compiled_module_main('None', lambda times, repeat: benchmark_compiled_module(args, times=times, repeat=repeat))
