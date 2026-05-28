module {
  func.func @main(%arg0: !torch.vtensor<[3,4],f32>, %arg1: !torch.vtensor<[2,3],si64>) -> !torch.vtensor<[3,2],f32> {
    %0 = torch.vtensor.literal(dense_resource<torch_tensor_2_4_torch.float32> : tensor<2x4xf32>) : !torch.vtensor<[2,4],f32>
    %none = torch.constant.none
    %1 = torch.aten.linear %arg0, %0, %none : !torch.vtensor<[3,4],f32>, !torch.vtensor<[2,4],f32>, !torch.none -> !torch.vtensor<[3,2],f32>
    %int0 = torch.constant.int 0
    %int1 = torch.constant.int 1
    %2 = torch.aten.select.int %arg1, %int0, %int1 : !torch.vtensor<[2,3],si64>, !torch.int, !torch.int -> !torch.vtensor<[3],si64>
    %int0_0 = torch.constant.int 0
    %int0_1 = torch.constant.int 0
    %3 = torch.aten.select.int %arg1, %int0_0, %int0_1 : !torch.vtensor<[2,3],si64>, !torch.int, !torch.int -> !torch.vtensor<[3],si64>
    %int-2 = torch.constant.int -2
    %4 = torch.aten.index_select %1, %int-2, %3 : !torch.vtensor<[3,2],f32>, !torch.int, !torch.vtensor<[3],si64> -> !torch.vtensor<[3,2],f32>
    %int-1 = torch.constant.int -1
    %int1_2 = torch.constant.int 1
    %5 = torch.prim.ListConstruct %int-1, %int1_2 : (!torch.int, !torch.int) -> !torch.list<int>
    %6 = torch.aten.view %2, %5 : !torch.vtensor<[3],si64>, !torch.list<int> -> !torch.vtensor<[3,1],si64>
    %int3 = torch.constant.int 3
    %int2 = torch.constant.int 2
    %7 = torch.prim.ListConstruct %int3, %int2 : (!torch.int, !torch.int) -> !torch.list<int>
    %false = torch.constant.bool false
    %8 = torch.aten.expand %6, %7, %false : !torch.vtensor<[3,1],si64>, !torch.list<int>, !torch.bool -> !torch.vtensor<[3,2],si64>
    %int3_3 = torch.constant.int 3
    %int2_4 = torch.constant.int 2
    %9 = torch.prim.ListConstruct %int3_3, %int2_4 : (!torch.int, !torch.int) -> !torch.list<int>
    %none_5 = torch.constant.none
    %none_6 = torch.constant.none
    %none_7 = torch.constant.none
    %false_8 = torch.constant.bool false
    %10 = torch.aten.new_zeros %4, %9, %none_5, %none_6, %none_7, %false_8 : !torch.vtensor<[3,2],f32>, !torch.list<int>, !torch.none, !torch.none, !torch.none, !torch.bool -> !torch.vtensor<[3,2],f32>
    %int0_9 = torch.constant.int 0
    %11 = torch.aten.scatter_add %10, %int0_9, %8, %4 : !torch.vtensor<[3,2],f32>, !torch.int, !torch.vtensor<[3,2],si64>, !torch.vtensor<[3,2],f32> -> !torch.vtensor<[3,2],f32>
    return %11 : !torch.vtensor<[3,2],f32>
  }
}

{-#
  dialect_resources: {
    builtin: {
      torch_tensor_2_4_torch.float32: "0x0400000070BFB5BD4C7B873EACBB9ABE704849BEB89174BF528B29BFE80ED3BE00BB173D"
    }
  }
#-}
