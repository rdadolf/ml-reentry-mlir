#sparse = #sparse_tensor.encoding<{ map = (d0, d1) -> (d0 : dense, d1 : compressed), posWidth = 64, crdWidth = 64 }>
module {
  func.func @main(%arg0: !torch.vtensor<[5,4],f32>, %arg1: !torch.vtensor<[5,5],f32,#sparse>) -> !torch.vtensor<[5,3],f32> {
    %str = torch.constant.str "mean"
    %0 = torch.operator "torch.aten._sparse_mm.reduce"(%arg1, %arg0, %str) : (!torch.vtensor<[5,5],f32,#sparse>, !torch.vtensor<[5,4],f32>, !torch.str) -> !torch.vtensor<[5,4],f32>
    %1 = torch.vtensor.literal(dense_resource<torch_tensor_8_4_torch.float32> : tensor<8x4xf32>) : !torch.vtensor<[8,4],f32>
    %2 = torch.vtensor.literal(dense_resource<torch_tensor_8_torch.float32> : tensor<8xf32>) : !torch.vtensor<[8],f32>
    %3 = torch.aten.linear %0, %1, %2 : !torch.vtensor<[5,4],f32>, !torch.vtensor<[8,4],f32>, !torch.vtensor<[8],f32> -> !torch.vtensor<[5,8],f32>
    %4 = torch.vtensor.literal(dense_resource<torch_tensor_8_4_torch.float32_1> : tensor<8x4xf32>) : !torch.vtensor<[8,4],f32>
    %none = torch.constant.none
    %5 = torch.aten.linear %arg0, %4, %none : !torch.vtensor<[5,4],f32>, !torch.vtensor<[8,4],f32>, !torch.none -> !torch.vtensor<[5,8],f32>
    %int1 = torch.constant.int 1
    %6 = torch.aten.add.Tensor %3, %5, %int1 : !torch.vtensor<[5,8],f32>, !torch.vtensor<[5,8],f32>, !torch.int -> !torch.vtensor<[5,8],f32>
    %7 = torch.aten.relu %6 : !torch.vtensor<[5,8],f32> -> !torch.vtensor<[5,8],f32>
    %str_0 = torch.constant.str "mean"
    %8 = torch.operator "torch.aten._sparse_mm.reduce"(%arg1, %7, %str_0) : (!torch.vtensor<[5,5],f32,#sparse>, !torch.vtensor<[5,8],f32>, !torch.str) -> !torch.vtensor<[5,8],f32>
    %9 = torch.vtensor.literal(dense_resource<torch_tensor_3_8_torch.float32> : tensor<3x8xf32>) : !torch.vtensor<[3,8],f32>
    %10 = torch.vtensor.literal(dense_resource<torch_tensor_3_torch.float32> : tensor<3xf32>) : !torch.vtensor<[3],f32>
    %11 = torch.aten.linear %8, %9, %10 : !torch.vtensor<[5,8],f32>, !torch.vtensor<[3,8],f32>, !torch.vtensor<[3],f32> -> !torch.vtensor<[5,3],f32>
    %12 = torch.vtensor.literal(dense_resource<torch_tensor_3_8_torch.float32_1> : tensor<3x8xf32>) : !torch.vtensor<[3,8],f32>
    %none_1 = torch.constant.none
    %13 = torch.aten.linear %7, %12, %none_1 : !torch.vtensor<[5,8],f32>, !torch.vtensor<[3,8],f32>, !torch.none -> !torch.vtensor<[5,3],f32>
    %int1_2 = torch.constant.int 1
    %14 = torch.aten.add.Tensor %11, %13, %int1_2 : !torch.vtensor<[5,3],f32>, !torch.vtensor<[5,3],f32>, !torch.int -> !torch.vtensor<[5,3],f32>
    %int-1 = torch.constant.int -1
    %none_3 = torch.constant.none
    %15 = torch.aten.log_softmax.int %14, %int-1, %none_3 : !torch.vtensor<[5,3],f32>, !torch.int, !torch.none -> !torch.vtensor<[5,3],f32>
    return %15 : !torch.vtensor<[5,3],f32>
  }
}

{-#
  dialect_resources: {
    builtin: {
      torch_tensor_8_4_torch.float32: "0x040000009838493ED01BD43EE8C5DE3E22E2E13E78CACB3DF89CDEBE90663C3DAC27A0BE8C94EEBE3E74E33EF0A6C23EFE5DFFBE08AABF3DC880ACBDB882A8BD1C5F6ABE8CE4443E34A197BEDCB13B3E1676813E5C43B73E48713F3E4A5FFDBE0011A6BE38A67F3E1853D63D96B3C7BEE86893BEF2D4F03E547FAC3EB03E5FBED4DC00BE",
      torch_tensor_8_torch.float32: "0x0400000078DDF3BE803E13BC78C8C0BEA277C5BE20B0E1BCA0BF993DF4AD51BE98E7973E",
      torch_tensor_8_4_torch.float32_1: "0x0400000038C99BBE6849E83ED06FAF3E64E1D7BE88DBFEBD80D2B83C1867953DD0DDF23D5CEC483EE059F53CCCD179BED445723E5691F5BEA0BB97BE3C2B00BEEC6679BE5C1D33BEBAD2D1BE00D2D9BDF8E2DA3D76C6A6BE4034D2BC0042B73EF08852BD80AC633CC0AD30BD103DCF3D60C6A23EBA7EF23E0693A23EC40CF33E601D14BD",
      torch_tensor_3_8_torch.float32: "0x04000000EB4B47BE40F652BE2773F73D5DBE57BEEDC1FCBB42AF733CE360693E0ED688BE428B78BED03852BE28677D3EE62302BE11B0983E79EA023EC25F373D487B2CBB01238FBDD6B1353DD656A5BD4ACE22BB43C6383D21988DBE7FC13DBEFB2B923E",
      torch_tensor_3_torch.float32: "0x04000000D8E792BE13F9CFBC4312B33E",
      torch_tensor_3_8_torch.float32_1: "0x0400000023C8023EB401243C87DF9CBE9058333EC4EF80BE288ACDBD95F0F2BD147456BDFF717D3B5D4E953E33C9343D4123A23EAC765D3ECAE264BE3660223E78EC7FBEEB7019BEB3F7D43DA915EF3D48CE873E8C17E9BDF25E143AD3623A3EF80FAFBE"
    }
  }
#-}
