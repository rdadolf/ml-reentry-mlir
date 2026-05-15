#sparse = #sparse_tensor.encoding<{ map = (d0, d1) -> (d0 : dense, d1 : compressed), posWidth = 64, crdWidth = 64 }>
module {
  func.func @main(%arg0: !torch.vtensor<[3,3],f32,#sparse>, %arg1: !torch.vtensor<[3,4],f32>) -> !torch.vtensor<[3,4],f32> {
    %0 = torch.aten.matmul %arg0, %arg1 : !torch.vtensor<[3,3],f32,#sparse>, !torch.vtensor<[3,4],f32> -> !torch.vtensor<[3,4],f32>
    return %0 : !torch.vtensor<[3,4],f32>
  }
}
