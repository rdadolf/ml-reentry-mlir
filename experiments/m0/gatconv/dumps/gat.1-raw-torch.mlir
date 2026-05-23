module {
  func.func @main(%arg0: !torch.vtensor<[3,4],f32>, %arg1: !torch.vtensor<[2,3],si64>) -> !torch.vtensor<[3,4],f32> {
    %0 = torch.vtensor.literal(dense_resource<torch_tensor_4_4_torch.float32> : tensor<4x4xf32>) : !torch.vtensor<[4,4],f32>
    %none = torch.constant.none
    %1 = torch.aten.linear %arg0, %0, %none : !torch.vtensor<[3,4],f32>, !torch.vtensor<[4,4],f32>, !torch.none -> !torch.vtensor<[3,4],f32>
    %int-1 = torch.constant.int -1
    %int2 = torch.constant.int 2
    %int2_0 = torch.constant.int 2
    %2 = torch.prim.ListConstruct %int-1, %int2, %int2_0 : (!torch.int, !torch.int, !torch.int) -> !torch.list<int>
    %3 = torch.aten.view %1, %2 : !torch.vtensor<[3,4],f32>, !torch.list<int> -> !torch.vtensor<[3,2,2],f32>
    %4 = torch.vtensor.literal(dense_resource<torch_tensor_1_2_2_torch.float32> : tensor<1x2x2xf32>) : !torch.vtensor<[1,2,2],f32>
    %5 = torch.aten.mul.Tensor %3, %4 : !torch.vtensor<[3,2,2],f32>, !torch.vtensor<[1,2,2],f32> -> !torch.vtensor<[3,2,2],f32>
    %int-1_1 = torch.constant.int -1
    %6 = torch.prim.ListConstruct %int-1_1 : (!torch.int) -> !torch.list<int>
    %false = torch.constant.bool false
    %none_2 = torch.constant.none
    %7 = torch.aten.sum.dim_IntList %5, %6, %false, %none_2 : !torch.vtensor<[3,2,2],f32>, !torch.list<int>, !torch.bool, !torch.none -> !torch.vtensor<[3,2],f32>
    %8 = torch.vtensor.literal(dense_resource<torch_tensor_1_2_2_torch.float32_1> : tensor<1x2x2xf32>) : !torch.vtensor<[1,2,2],f32>
    %9 = torch.aten.mul.Tensor %3, %8 : !torch.vtensor<[3,2,2],f32>, !torch.vtensor<[1,2,2],f32> -> !torch.vtensor<[3,2,2],f32>
    %int-1_3 = torch.constant.int -1
    %10 = torch.prim.ListConstruct %int-1_3 : (!torch.int) -> !torch.list<int>
    %false_4 = torch.constant.bool false
    %none_5 = torch.constant.none
    %11 = torch.aten.sum.dim_IntList %9, %10, %false_4, %none_5 : !torch.vtensor<[3,2,2],f32>, !torch.list<int>, !torch.bool, !torch.none -> !torch.vtensor<[3,2],f32>
    %int0 = torch.constant.int 0
    %int1 = torch.constant.int 1
    %12 = torch.aten.select.int %arg1, %int0, %int1 : !torch.vtensor<[2,3],si64>, !torch.int, !torch.int -> !torch.vtensor<[3],si64>
    %int0_6 = torch.constant.int 0
    %int0_7 = torch.constant.int 0
    %13 = torch.aten.select.int %arg1, %int0_6, %int0_7 : !torch.vtensor<[2,3],si64>, !torch.int, !torch.int -> !torch.vtensor<[3],si64>
    %int0_8 = torch.constant.int 0
    %14 = torch.aten.index_select %7, %int0_8, %13 : !torch.vtensor<[3,2],f32>, !torch.int, !torch.vtensor<[3],si64> -> !torch.vtensor<[3,2],f32>
    %int0_9 = torch.constant.int 0
    %15 = torch.aten.index_select %11, %int0_9, %12 : !torch.vtensor<[3,2],f32>, !torch.int, !torch.vtensor<[3],si64> -> !torch.vtensor<[3,2],f32>
    %int1_10 = torch.constant.int 1
    %16 = torch.aten.add.Tensor %14, %15, %int1_10 : !torch.vtensor<[3,2],f32>, !torch.vtensor<[3,2],f32>, !torch.int -> !torch.vtensor<[3,2],f32>
    %float2.000000e-01 = torch.constant.float 2.000000e-01
    %17 = torch.aten.leaky_relu %16, %float2.000000e-01 : !torch.vtensor<[3,2],f32>, !torch.float -> !torch.vtensor<[3,2],f32>
    %18 = torch.aten.detach %17 : !torch.vtensor<[3,2],f32> -> !torch.vtensor<[3,2],f32>
    %int-1_11 = torch.constant.int -1
    %int1_12 = torch.constant.int 1
    %19 = torch.prim.ListConstruct %int-1_11, %int1_12 : (!torch.int, !torch.int) -> !torch.list<int>
    %20 = torch.aten.view %12, %19 : !torch.vtensor<[3],si64>, !torch.list<int> -> !torch.vtensor<[3,1],si64>
    %int3 = torch.constant.int 3
    %int2_13 = torch.constant.int 2
    %21 = torch.prim.ListConstruct %int3, %int2_13 : (!torch.int, !torch.int) -> !torch.list<int>
    %false_14 = torch.constant.bool false
    %22 = torch.aten.expand %20, %21, %false_14 : !torch.vtensor<[3,1],si64>, !torch.list<int>, !torch.bool -> !torch.vtensor<[3,2],si64>
    %int3_15 = torch.constant.int 3
    %int2_16 = torch.constant.int 2
    %23 = torch.prim.ListConstruct %int3_15, %int2_16 : (!torch.int, !torch.int) -> !torch.list<int>
    %none_17 = torch.constant.none
    %none_18 = torch.constant.none
    %none_19 = torch.constant.none
    %false_20 = torch.constant.bool false
    %24 = torch.aten.new_zeros %18, %23, %none_17, %none_18, %none_19, %false_20 : !torch.vtensor<[3,2],f32>, !torch.list<int>, !torch.none, !torch.none, !torch.none, !torch.bool -> !torch.vtensor<[3,2],f32>
    %int0_21 = torch.constant.int 0
    %str = torch.constant.str "amax"
    %false_22 = torch.constant.bool false
    %25 = torch.aten.scatter_reduce.two %24, %int0_21, %22, %18, %str, %false_22 : !torch.vtensor<[3,2],f32>, !torch.int, !torch.vtensor<[3,2],si64>, !torch.vtensor<[3,2],f32>, !torch.str, !torch.bool -> !torch.vtensor<[3,2],f32>
    %int0_23 = torch.constant.int 0
    %26 = torch.aten.index_select %25, %int0_23, %12 : !torch.vtensor<[3,2],f32>, !torch.int, !torch.vtensor<[3],si64> -> !torch.vtensor<[3,2],f32>
    %int1_24 = torch.constant.int 1
    %27 = torch.aten.sub.Tensor %17, %26, %int1_24 : !torch.vtensor<[3,2],f32>, !torch.vtensor<[3,2],f32>, !torch.int -> !torch.vtensor<[3,2],f32>
    %28 = torch.aten.exp %27 : !torch.vtensor<[3,2],f32> -> !torch.vtensor<[3,2],f32>
    %int-1_25 = torch.constant.int -1
    %int1_26 = torch.constant.int 1
    %29 = torch.prim.ListConstruct %int-1_25, %int1_26 : (!torch.int, !torch.int) -> !torch.list<int>
    %30 = torch.aten.view %12, %29 : !torch.vtensor<[3],si64>, !torch.list<int> -> !torch.vtensor<[3,1],si64>
    %int3_27 = torch.constant.int 3
    %int2_28 = torch.constant.int 2
    %31 = torch.prim.ListConstruct %int3_27, %int2_28 : (!torch.int, !torch.int) -> !torch.list<int>
    %false_29 = torch.constant.bool false
    %32 = torch.aten.expand %30, %31, %false_29 : !torch.vtensor<[3,1],si64>, !torch.list<int>, !torch.bool -> !torch.vtensor<[3,2],si64>
    %int3_30 = torch.constant.int 3
    %int2_31 = torch.constant.int 2
    %33 = torch.prim.ListConstruct %int3_30, %int2_31 : (!torch.int, !torch.int) -> !torch.list<int>
    %none_32 = torch.constant.none
    %none_33 = torch.constant.none
    %none_34 = torch.constant.none
    %false_35 = torch.constant.bool false
    %34 = torch.aten.new_zeros %28, %33, %none_32, %none_33, %none_34, %false_35 : !torch.vtensor<[3,2],f32>, !torch.list<int>, !torch.none, !torch.none, !torch.none, !torch.bool -> !torch.vtensor<[3,2],f32>
    %int0_36 = torch.constant.int 0
    %35 = torch.aten.scatter_add %34, %int0_36, %32, %28 : !torch.vtensor<[3,2],f32>, !torch.int, !torch.vtensor<[3,2],si64>, !torch.vtensor<[3,2],f32> -> !torch.vtensor<[3,2],f32>
    %float9.999990e-17 = torch.constant.float 9.9999999999999997E-17
    %int1_37 = torch.constant.int 1
    %36 = torch.aten.add.Scalar %35, %float9.999990e-17, %int1_37 : !torch.vtensor<[3,2],f32>, !torch.float, !torch.int -> !torch.vtensor<[3,2],f32>
    %int0_38 = torch.constant.int 0
    %37 = torch.aten.index_select %36, %int0_38, %12 : !torch.vtensor<[3,2],f32>, !torch.int, !torch.vtensor<[3],si64> -> !torch.vtensor<[3,2],f32>
    %38 = torch.aten.div.Tensor %28, %37 : !torch.vtensor<[3,2],f32>, !torch.vtensor<[3,2],f32> -> !torch.vtensor<[3,2],f32>
    %none_39 = torch.constant.none
    %39 = torch.aten.clone %38, %none_39 : !torch.vtensor<[3,2],f32>, !torch.none -> !torch.vtensor<[3,2],f32>
    %int0_40 = torch.constant.int 0
    %int1_41 = torch.constant.int 1
    %40 = torch.aten.select.int %arg1, %int0_40, %int1_41 : !torch.vtensor<[2,3],si64>, !torch.int, !torch.int -> !torch.vtensor<[3],si64>
    %int0_42 = torch.constant.int 0
    %int0_43 = torch.constant.int 0
    %41 = torch.aten.select.int %arg1, %int0_42, %int0_43 : !torch.vtensor<[2,3],si64>, !torch.int, !torch.int -> !torch.vtensor<[3],si64>
    %int0_44 = torch.constant.int 0
    %42 = torch.aten.index_select %3, %int0_44, %41 : !torch.vtensor<[3,2,2],f32>, !torch.int, !torch.vtensor<[3],si64> -> !torch.vtensor<[3,2,2],f32>
    %int-1_45 = torch.constant.int -1
    %43 = torch.aten.unsqueeze %39, %int-1_45 : !torch.vtensor<[3,2],f32>, !torch.int -> !torch.vtensor<[3,2,1],f32>
    %44 = torch.aten.mul.Tensor %43, %42 : !torch.vtensor<[3,2,1],f32>, !torch.vtensor<[3,2,2],f32> -> !torch.vtensor<[3,2,2],f32>
    %int-1_46 = torch.constant.int -1
    %int1_47 = torch.constant.int 1
    %int1_48 = torch.constant.int 1
    %45 = torch.prim.ListConstruct %int-1_46, %int1_47, %int1_48 : (!torch.int, !torch.int, !torch.int) -> !torch.list<int>
    %46 = torch.aten.view %40, %45 : !torch.vtensor<[3],si64>, !torch.list<int> -> !torch.vtensor<[3,1,1],si64>
    %int3_49 = torch.constant.int 3
    %int2_50 = torch.constant.int 2
    %int2_51 = torch.constant.int 2
    %47 = torch.prim.ListConstruct %int3_49, %int2_50, %int2_51 : (!torch.int, !torch.int, !torch.int) -> !torch.list<int>
    %false_52 = torch.constant.bool false
    %48 = torch.aten.expand %46, %47, %false_52 : !torch.vtensor<[3,1,1],si64>, !torch.list<int>, !torch.bool -> !torch.vtensor<[3,2,2],si64>
    %int3_53 = torch.constant.int 3
    %int2_54 = torch.constant.int 2
    %int2_55 = torch.constant.int 2
    %49 = torch.prim.ListConstruct %int3_53, %int2_54, %int2_55 : (!torch.int, !torch.int, !torch.int) -> !torch.list<int>
    %none_56 = torch.constant.none
    %none_57 = torch.constant.none
    %none_58 = torch.constant.none
    %false_59 = torch.constant.bool false
    %50 = torch.aten.new_zeros %44, %49, %none_56, %none_57, %none_58, %false_59 : !torch.vtensor<[3,2,2],f32>, !torch.list<int>, !torch.none, !torch.none, !torch.none, !torch.bool -> !torch.vtensor<[3,2,2],f32>
    %int0_60 = torch.constant.int 0
    %51 = torch.aten.scatter_add %50, %int0_60, %48, %44 : !torch.vtensor<[3,2,2],f32>, !torch.int, !torch.vtensor<[3,2,2],si64>, !torch.vtensor<[3,2,2],f32> -> !torch.vtensor<[3,2,2],f32>
    %int-1_61 = torch.constant.int -1
    %int4 = torch.constant.int 4
    %52 = torch.prim.ListConstruct %int-1_61, %int4 : (!torch.int, !torch.int) -> !torch.list<int>
    %53 = torch.aten.view %51, %52 : !torch.vtensor<[3,2,2],f32>, !torch.list<int> -> !torch.vtensor<[3,4],f32>
    return %53 : !torch.vtensor<[3,4],f32>
  }
}

{-#
  dialect_resources: {
    builtin: {
      torch_tensor_4_4_torch.float32: "0x040000002A4BAF3ECC06053F1E4D16BF1E16C1BE630DA13E5E19383F728136BE10E7253F63F00EBE8BACBB3D10BF483FB6AA4DBFF4910BBF6D8260BED9D6ACBE178D3F3F",
      torch_tensor_1_2_2_torch.float32: "0x04000000103A4BBF905410BF4C0C5BBF7BD292BF",
      torch_tensor_1_2_2_torch.float32_1: "0x04000000DC0537BFC5C1863FAAE70B3F2FF6173F"
    }
  }
#-}
