module {
  llvm.func @malloc(i64) -> !llvm.ptr
  llvm.mlir.global private constant @__constant_3x2xf32(dense<0.000000e+00> : tensor<3x2xf32>) {addr_space = 0 : i32, alignment = 64 : i64} : !llvm.array<3 x array<2 x f32>>
  llvm.func @main(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: i64, %arg3: i64, %arg4: i64, %arg5: i64, %arg6: i64, %arg7: !llvm.ptr, %arg8: !llvm.ptr, %arg9: i64, %arg10: i64, %arg11: i64, %arg12: i64, %arg13: i64) -> !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> {
    %0 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %1 = llvm.insertvalue %arg7, %0[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %2 = llvm.insertvalue %arg8, %1[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %3 = llvm.insertvalue %arg9, %2[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %4 = llvm.insertvalue %arg10, %3[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %5 = llvm.insertvalue %arg12, %4[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %6 = llvm.insertvalue %arg11, %5[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %7 = llvm.insertvalue %arg13, %6[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %8 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %9 = llvm.insertvalue %arg0, %8[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %10 = llvm.insertvalue %arg1, %9[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %11 = llvm.insertvalue %arg2, %10[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %12 = llvm.insertvalue %arg3, %11[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %13 = llvm.insertvalue %arg5, %12[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %14 = llvm.insertvalue %arg4, %13[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %15 = llvm.insertvalue %arg6, %14[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %16 = llvm.mlir.constant(4 : index) : i64
    %17 = llvm.mlir.constant(2 : index) : i64
    %18 = llvm.mlir.constant(1 : index) : i64
    %19 = llvm.mlir.constant(3 : index) : i64
    %20 = llvm.mlir.constant(0 : index) : i64
    %21 = llvm.mlir.constant(3 : index) : i64
    %22 = llvm.mlir.constant(2 : index) : i64
    %23 = llvm.mlir.constant(1 : index) : i64
    %24 = llvm.mlir.constant(6 : index) : i64
    %25 = llvm.mlir.zero : !llvm.ptr
    %26 = llvm.getelementptr %25[%24] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %27 = llvm.ptrtoint %26 : !llvm.ptr to i64
    %28 = llvm.mlir.addressof @__constant_3x2xf32 : !llvm.ptr
    %29 = llvm.getelementptr %28[0, 0, 0] : (!llvm.ptr) -> !llvm.ptr, !llvm.array<3 x array<2 x f32>>
    %30 = llvm.mlir.constant(3735928559 : index) : i64
    %31 = llvm.inttoptr %30 : i64 to !llvm.ptr
    %32 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %33 = llvm.insertvalue %31, %32[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %34 = llvm.insertvalue %29, %33[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %35 = llvm.mlir.constant(0 : index) : i64
    %36 = llvm.insertvalue %35, %34[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %37 = llvm.insertvalue %21, %36[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %38 = llvm.insertvalue %22, %37[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %39 = llvm.insertvalue %22, %38[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %40 = llvm.insertvalue %23, %39[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %41 = llvm.mlir.constant(3 : index) : i64
    %42 = llvm.mlir.constant(2 : index) : i64
    %43 = llvm.mlir.constant(1 : index) : i64
    %44 = llvm.mlir.constant(6 : index) : i64
    %45 = llvm.mlir.zero : !llvm.ptr
    %46 = llvm.getelementptr %45[%44] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %47 = llvm.ptrtoint %46 : !llvm.ptr to i64
    %48 = llvm.mlir.constant(64 : index) : i64
    %49 = llvm.add %47, %48 : i64
    %50 = llvm.call @malloc(%49) : (i64) -> !llvm.ptr
    %51 = llvm.ptrtoint %50 : !llvm.ptr to i64
    %52 = llvm.mlir.constant(1 : index) : i64
    %53 = llvm.sub %48, %52 : i64
    %54 = llvm.add %51, %53 : i64
    %55 = llvm.urem %54, %48 : i64
    %56 = llvm.sub %54, %55 : i64
    %57 = llvm.inttoptr %56 : i64 to !llvm.ptr
    %58 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %59 = llvm.insertvalue %50, %58[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %60 = llvm.insertvalue %57, %59[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %61 = llvm.mlir.constant(0 : index) : i64
    %62 = llvm.insertvalue %61, %60[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %63 = llvm.insertvalue %41, %62[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %64 = llvm.insertvalue %42, %63[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %65 = llvm.insertvalue %42, %64[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %66 = llvm.insertvalue %43, %65[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %67 = llvm.mlir.constant(1 : index) : i64
    %68 = llvm.extractvalue %40[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %69 = llvm.mul %67, %68 : i64
    %70 = llvm.extractvalue %40[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %71 = llvm.mul %69, %70 : i64
    %72 = llvm.mlir.zero : !llvm.ptr
    %73 = llvm.getelementptr %72[1] : (!llvm.ptr) -> !llvm.ptr, f32
    %74 = llvm.ptrtoint %73 : !llvm.ptr to i64
    %75 = llvm.mul %71, %74 : i64
    %76 = llvm.extractvalue %40[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %77 = llvm.extractvalue %40[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %78 = llvm.getelementptr %76[%77] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %79 = llvm.extractvalue %66[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %80 = llvm.extractvalue %66[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %81 = llvm.getelementptr %79[%80] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "llvm.intr.memcpy"(%81, %78, %75) <{isVolatile = false}> : (!llvm.ptr, !llvm.ptr, i64) -> ()
    llvm.br ^bb1(%20 : i64)
  ^bb1(%82: i64):  // 2 preds: ^bb0, ^bb8
    %83 = llvm.icmp "slt" %82, %19 : i64
    llvm.cond_br %83, ^bb2, ^bb9
  ^bb2:  // pred: ^bb1
    llvm.br ^bb3(%20 : i64)
  ^bb3(%84: i64):  // 2 preds: ^bb2, ^bb7
    %85 = llvm.icmp "slt" %84, %17 : i64
    llvm.cond_br %85, ^bb4, ^bb8
  ^bb4:  // pred: ^bb3
    llvm.br ^bb5(%20 : i64)
  ^bb5(%86: i64):  // 2 preds: ^bb4, ^bb6
    %87 = llvm.icmp "slt" %86, %16 : i64
    llvm.cond_br %87, ^bb6, ^bb7
  ^bb6:  // pred: ^bb5
    %88 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %89 = llvm.mlir.constant(4 : index) : i64
    %90 = llvm.mul %82, %89 overflow<nsw, nuw> : i64
    %91 = llvm.add %90, %86 overflow<nsw, nuw> : i64
    %92 = llvm.getelementptr inbounds|nuw %88[%91] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %93 = llvm.load %92 : !llvm.ptr -> f32
    %94 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %95 = llvm.mlir.constant(2 : index) : i64
    %96 = llvm.mul %86, %95 overflow<nsw, nuw> : i64
    %97 = llvm.add %96, %84 overflow<nsw, nuw> : i64
    %98 = llvm.getelementptr inbounds|nuw %94[%97] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %99 = llvm.load %98 : !llvm.ptr -> f32
    %100 = llvm.extractvalue %66[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %101 = llvm.mlir.constant(2 : index) : i64
    %102 = llvm.mul %82, %101 overflow<nsw, nuw> : i64
    %103 = llvm.add %102, %84 overflow<nsw, nuw> : i64
    %104 = llvm.getelementptr inbounds|nuw %100[%103] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %105 = llvm.load %104 : !llvm.ptr -> f32
    %106 = llvm.fmul %93, %99 : f32
    %107 = llvm.fadd %105, %106 : f32
    %108 = llvm.extractvalue %66[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %109 = llvm.mlir.constant(2 : index) : i64
    %110 = llvm.mul %82, %109 overflow<nsw, nuw> : i64
    %111 = llvm.add %110, %84 overflow<nsw, nuw> : i64
    %112 = llvm.getelementptr inbounds|nuw %108[%111] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %107, %112 : f32, !llvm.ptr
    %113 = llvm.add %86, %18 : i64
    llvm.br ^bb5(%113 : i64)
  ^bb7:  // pred: ^bb5
    %114 = llvm.add %84, %18 : i64
    llvm.br ^bb3(%114 : i64)
  ^bb8:  // pred: ^bb3
    %115 = llvm.add %82, %18 : i64
    llvm.br ^bb1(%115 : i64)
  ^bb9:  // pred: ^bb1
    llvm.return %66 : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
  }
}

