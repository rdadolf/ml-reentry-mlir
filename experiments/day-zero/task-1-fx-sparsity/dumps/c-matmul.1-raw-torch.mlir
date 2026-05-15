module {
  func.func @main(%arg0: !torch.vtensor<[3,4],f32>, %arg1: !torch.vtensor<[4,2],f32>) -> !torch.vtensor<[3,2],f32> {
    %0 = torch.aten.matmul %arg0, %arg1 : !torch.vtensor<[3,4],f32>, !torch.vtensor<[4,2],f32> -> !torch.vtensor<[3,2],f32>
    return %0 : !torch.vtensor<[3,2],f32>
  }
}
