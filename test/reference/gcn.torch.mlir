#sparse = #sparse_tensor.encoding<{ map = (d0, d1) -> (d0 : dense, d1 : compressed), posWidth = 64, crdWidth = 64 }>
module {
  func.func @main(%arg0: !torch.vtensor<[5,4],f32>, %arg1: !torch.vtensor<[5,5],f32,#sparse>) -> !torch.vtensor<[5,3],f32> {
    %none = torch.constant.none
    %float1.000000e00 = torch.constant.float 1.000000e+00
    %true = torch.constant.bool true
    %int-1 = torch.constant.int -1
    %0 = torch.vtensor.literal(dense_resource<torch_tensor_3_torch.float32> : tensor<3xf32>) : !torch.vtensor<[3],f32>
    %1 = torch.vtensor.literal(dense_resource<torch_tensor_3_8_torch.float32> : tensor<3x8xf32>) : !torch.vtensor<[3,8],f32>
    %int1 = torch.constant.int 1
    %2 = torch.vtensor.literal(dense_resource<torch_tensor_8_torch.float32> : tensor<8xf32>) : !torch.vtensor<[8],f32>
    %3 = torch.vtensor.literal(dense_resource<torch_tensor_8_4_torch.float32> : tensor<8x4xf32>) : !torch.vtensor<[8,4],f32>
    %int0 = torch.constant.int 0
    %4 = torch.aten.transpose.int %3, %int0, %int1 : !torch.vtensor<[8,4],f32>, !torch.int, !torch.int -> !torch.vtensor<[4,8],f32>
    %5 = torch.aten.mm %arg0, %4 : !torch.vtensor<[5,4],f32>, !torch.vtensor<[4,8],f32> -> !torch.vtensor<[5,8],f32>
    %6 = torch.aten.mm %arg1, %5 : !torch.vtensor<[5,5],f32,#sparse>, !torch.vtensor<[5,8],f32> -> !torch.vtensor<[5,8],f32>
    %7 = torch.aten.add.Tensor %6, %2, %int1 : !torch.vtensor<[5,8],f32>, !torch.vtensor<[8],f32>, !torch.int -> !torch.vtensor<[5,8],f32>
    %8 = torch.aten.relu %7 : !torch.vtensor<[5,8],f32> -> !torch.vtensor<[5,8],f32>
    %9 = torch.aten.transpose.int %1, %int0, %int1 : !torch.vtensor<[3,8],f32>, !torch.int, !torch.int -> !torch.vtensor<[8,3],f32>
    %10 = torch.aten.mm %8, %9 : !torch.vtensor<[5,8],f32>, !torch.vtensor<[8,3],f32> -> !torch.vtensor<[5,3],f32>
    %11 = torch.aten.mm %arg1, %10 : !torch.vtensor<[5,5],f32,#sparse>, !torch.vtensor<[5,3],f32> -> !torch.vtensor<[5,3],f32>
    %12 = torch.aten.add.Tensor %11, %0, %int1 : !torch.vtensor<[5,3],f32>, !torch.vtensor<[3],f32>, !torch.int -> !torch.vtensor<[5,3],f32>
    %values, %indices = torch.aten.max.dim %12, %int-1, %true : !torch.vtensor<[5,3],f32>, !torch.int, !torch.bool -> !torch.vtensor<[5,1],f32>, !torch.vtensor<[5,1],si64>
    %13 = torch.aten.sub.Tensor %12, %values, %float1.000000e00 : !torch.vtensor<[5,3],f32>, !torch.vtensor<[5,1],f32>, !torch.float -> !torch.vtensor<[5,3],f32>
    %14 = torch.aten.exp %13 : !torch.vtensor<[5,3],f32> -> !torch.vtensor<[5,3],f32>
    %15 = torch.prim.ListConstruct %int-1 : (!torch.int) -> !torch.list<int>
    %16 = torch.aten.sum.dim_IntList %14, %15, %true, %none : !torch.vtensor<[5,3],f32>, !torch.list<int>, !torch.bool, !torch.none -> !torch.vtensor<[5,1],f32>
    %17 = torch.aten.log %16 : !torch.vtensor<[5,1],f32> -> !torch.vtensor<[5,1],f32>
    %18 = torch.aten.sub.Tensor %13, %17, %float1.000000e00 : !torch.vtensor<[5,3],f32>, !torch.vtensor<[5,1],f32>, !torch.float -> !torch.vtensor<[5,3],f32>
    return %18 : !torch.vtensor<[5,3],f32>
  }
}

{-#
  dialect_resources: {
    builtin: {
      torch_tensor_3_torch.float32: "0x04000000000000000000000000000000",
      torch_tensor_3_8_torch.float32: "0x04000000396A913ECFF8DFBE2C9F8A3E1B3ABF3E4A59073FC1638D3EB7203BBFDD4BF5BE3CCFBC3E094A1E3E457D13BF1BBDD9BEB8DD313FA6CBFE3E94E0A4BEBA573EBE381B34BF777E59BC37610EBFDBD611BF7FAE26BD051AE33DCCDB9ABEC860E03E",
      torch_tensor_8_torch.float32: "0x040000000000000000000000000000000000000000000000000000000000000000000000",
      torch_tensor_8_4_torch.float32: "0x0400000085AAEABE86A8A6BE53EFFCBE208929BF2D56D3BE979A1B3F5E8CA13E5F78AF3E4952183D7B9CB9BE6E01F53D4D0429BF68CC02BF4CA4BABE876CE43E5D45D43EF68FA0BEF202D1BCB38BE73E12F5333FCBAF8F3EA6A2C33DF2BDF23E522BD5BE70ED063E65580CBF8AECFABEF205BBBE10D0A33EFD98913E5B74D6BEB8BF5A3E"
    }
  }
#-}
