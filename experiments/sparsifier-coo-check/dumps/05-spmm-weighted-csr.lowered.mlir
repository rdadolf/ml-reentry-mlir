module {
  llvm.func @malloc(i64) -> !llvm.ptr
  llvm.mlir.global private constant @__constant_8x4xf32(dense<0.000000e+00> : tensor<8x4xf32>) {addr_space = 0 : i32, alignment = 64 : i64} : !llvm.array<8 x array<4 x f32>>
  llvm.func @delSparseTensor(!llvm.ptr) attributes {sym_visibility = "private"}
  llvm.func @endLexInsert(!llvm.ptr) attributes {sym_visibility = "private"}
  llvm.func private @lexInsertF32(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: !llvm.ptr, %arg3: i64, %arg4: i64, %arg5: i64, %arg6: !llvm.ptr, %arg7: !llvm.ptr, %arg8: i64) attributes {llvm.emit_c_interface, sym_visibility = "private"} {
    %0 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %1 = llvm.insertvalue %arg1, %0[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %2 = llvm.insertvalue %arg2, %1[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %3 = llvm.insertvalue %arg3, %2[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %4 = llvm.insertvalue %arg4, %3[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %5 = llvm.insertvalue %arg5, %4[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %6 = llvm.mlir.constant(1 : index) : i64
    %7 = llvm.alloca %6 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.store %5, %7 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>, !llvm.ptr
    %8 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64)>
    %9 = llvm.insertvalue %arg6, %8[0] : !llvm.struct<(ptr, ptr, i64)> 
    %10 = llvm.insertvalue %arg7, %9[1] : !llvm.struct<(ptr, ptr, i64)> 
    %11 = llvm.insertvalue %arg8, %10[2] : !llvm.struct<(ptr, ptr, i64)> 
    %12 = llvm.mlir.constant(1 : index) : i64
    %13 = llvm.alloca %12 x !llvm.struct<(ptr, ptr, i64)> : (i64) -> !llvm.ptr
    llvm.store %11, %13 : !llvm.struct<(ptr, ptr, i64)>, !llvm.ptr
    llvm.call @_mlir_ciface_lexInsertF32(%arg0, %7, %13) : (!llvm.ptr, !llvm.ptr, !llvm.ptr) -> ()
    llvm.return
  }
  llvm.func @_mlir_ciface_lexInsertF32(!llvm.ptr, !llvm.ptr, !llvm.ptr) attributes {llvm.emit_c_interface, sym_visibility = "private"}
  llvm.func private @newSparseTensor(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: i64, %arg3: i64, %arg4: i64, %arg5: !llvm.ptr, %arg6: !llvm.ptr, %arg7: i64, %arg8: i64, %arg9: i64, %arg10: !llvm.ptr, %arg11: !llvm.ptr, %arg12: i64, %arg13: i64, %arg14: i64, %arg15: !llvm.ptr, %arg16: !llvm.ptr, %arg17: i64, %arg18: i64, %arg19: i64, %arg20: !llvm.ptr, %arg21: !llvm.ptr, %arg22: i64, %arg23: i64, %arg24: i64, %arg25: i32, %arg26: i32, %arg27: i32, %arg28: i32, %arg29: !llvm.ptr) -> !llvm.ptr attributes {llvm.emit_c_interface, sym_visibility = "private"} {
    %0 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %1 = llvm.insertvalue %arg0, %0[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %2 = llvm.insertvalue %arg1, %1[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %3 = llvm.insertvalue %arg2, %2[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %4 = llvm.insertvalue %arg3, %3[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %5 = llvm.insertvalue %arg4, %4[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %6 = llvm.mlir.constant(1 : index) : i64
    %7 = llvm.alloca %6 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.store %5, %7 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>, !llvm.ptr
    %8 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %9 = llvm.insertvalue %arg5, %8[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %10 = llvm.insertvalue %arg6, %9[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %11 = llvm.insertvalue %arg7, %10[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %12 = llvm.insertvalue %arg8, %11[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %13 = llvm.insertvalue %arg9, %12[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %14 = llvm.mlir.constant(1 : index) : i64
    %15 = llvm.alloca %14 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.store %13, %15 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>, !llvm.ptr
    %16 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %17 = llvm.insertvalue %arg10, %16[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %18 = llvm.insertvalue %arg11, %17[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %19 = llvm.insertvalue %arg12, %18[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %20 = llvm.insertvalue %arg13, %19[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %21 = llvm.insertvalue %arg14, %20[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %22 = llvm.mlir.constant(1 : index) : i64
    %23 = llvm.alloca %22 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.store %21, %23 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>, !llvm.ptr
    %24 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %25 = llvm.insertvalue %arg15, %24[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %26 = llvm.insertvalue %arg16, %25[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %27 = llvm.insertvalue %arg17, %26[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %28 = llvm.insertvalue %arg18, %27[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %29 = llvm.insertvalue %arg19, %28[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %30 = llvm.mlir.constant(1 : index) : i64
    %31 = llvm.alloca %30 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.store %29, %31 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>, !llvm.ptr
    %32 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %33 = llvm.insertvalue %arg20, %32[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %34 = llvm.insertvalue %arg21, %33[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %35 = llvm.insertvalue %arg22, %34[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %36 = llvm.insertvalue %arg23, %35[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %37 = llvm.insertvalue %arg24, %36[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %38 = llvm.mlir.constant(1 : index) : i64
    %39 = llvm.alloca %38 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.store %37, %39 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>, !llvm.ptr
    %40 = llvm.call @_mlir_ciface_newSparseTensor(%7, %15, %23, %31, %39, %arg25, %arg26, %arg27, %arg28, %arg29) : (!llvm.ptr, !llvm.ptr, !llvm.ptr, !llvm.ptr, !llvm.ptr, i32, i32, i32, i32, !llvm.ptr) -> !llvm.ptr
    llvm.return %40 : !llvm.ptr
  }
  llvm.func @_mlir_ciface_newSparseTensor(!llvm.ptr, !llvm.ptr, !llvm.ptr, !llvm.ptr, !llvm.ptr, i32, i32, i32, i32, !llvm.ptr) -> !llvm.ptr attributes {llvm.emit_c_interface, sym_visibility = "private"}
  llvm.func private @sparseCoordinates32(%arg0: !llvm.ptr, %arg1: i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> attributes {llvm.emit_c_interface, sym_visibility = "private"} {
    %0 = llvm.mlir.constant(1 : index) : i64
    %1 = llvm.alloca %0 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.call @_mlir_ciface_sparseCoordinates32(%1, %arg0, %arg1) : (!llvm.ptr, !llvm.ptr, i64) -> ()
    %2 = llvm.load %1 : !llvm.ptr -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.return %2 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  }
  llvm.func @_mlir_ciface_sparseCoordinates32(!llvm.ptr, !llvm.ptr, i64) attributes {llvm.emit_c_interface, sym_visibility = "private"}
  llvm.func private @sparsePositions32(%arg0: !llvm.ptr, %arg1: i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> attributes {llvm.emit_c_interface, sym_visibility = "private"} {
    %0 = llvm.mlir.constant(1 : index) : i64
    %1 = llvm.alloca %0 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.call @_mlir_ciface_sparsePositions32(%1, %arg0, %arg1) : (!llvm.ptr, !llvm.ptr, i64) -> ()
    %2 = llvm.load %1 : !llvm.ptr -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.return %2 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  }
  llvm.func @_mlir_ciface_sparsePositions32(!llvm.ptr, !llvm.ptr, i64) attributes {llvm.emit_c_interface, sym_visibility = "private"}
  llvm.func private @sparseValuesF32(%arg0: !llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> attributes {llvm.emit_c_interface, sym_visibility = "private"} {
    %0 = llvm.mlir.constant(1 : index) : i64
    %1 = llvm.alloca %0 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.call @_mlir_ciface_sparseValuesF32(%1, %arg0) : (!llvm.ptr, !llvm.ptr) -> ()
    %2 = llvm.load %1 : !llvm.ptr -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.return %2 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  }
  llvm.func @_mlir_ciface_sparseValuesF32(!llvm.ptr, !llvm.ptr) attributes {llvm.emit_c_interface, sym_visibility = "private"}
  llvm.func @printMemrefF32(i64, !llvm.ptr) attributes {sym_visibility = "private"}
  llvm.func @weighted_spmm(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: !llvm.ptr, %arg3: i64, %arg4: i64, %arg5: i64, %arg6: i64, %arg7: i64, %arg8: !llvm.ptr, %arg9: !llvm.ptr, %arg10: i64, %arg11: i64, %arg12: i64, %arg13: i64, %arg14: i64) -> !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> {
    %0 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %1 = llvm.insertvalue %arg1, %0[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %2 = llvm.insertvalue %arg2, %1[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %3 = llvm.insertvalue %arg3, %2[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %4 = llvm.insertvalue %arg4, %3[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %5 = llvm.insertvalue %arg6, %4[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %6 = llvm.insertvalue %arg5, %5[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %7 = llvm.insertvalue %arg7, %6[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %8 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %9 = llvm.insertvalue %arg8, %8[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %10 = llvm.insertvalue %arg9, %9[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %11 = llvm.insertvalue %arg10, %10[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %12 = llvm.insertvalue %arg11, %11[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %13 = llvm.insertvalue %arg13, %12[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %14 = llvm.insertvalue %arg12, %13[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %15 = llvm.insertvalue %arg14, %14[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %16 = llvm.mlir.constant(1 : index) : i64
    %17 = llvm.mlir.constant(0 : index) : i64
    %18 = llvm.mlir.constant(4 : index) : i64
    %19 = llvm.mlir.constant(8 : index) : i64
    %20 = llvm.call @sparseValuesF32(%arg0) : (!llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %21 = llvm.call @sparsePositions32(%arg0, %16) : (!llvm.ptr, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %22 = llvm.call @sparseCoordinates32(%arg0, %16) : (!llvm.ptr, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.br ^bb1(%17 : i64)
  ^bb1(%23: i64):  // 2 preds: ^bb0, ^bb8
    %24 = llvm.icmp "slt" %23, %19 : i64
    llvm.cond_br %24, ^bb2, ^bb9
  ^bb2:  // pred: ^bb1
    %25 = llvm.extractvalue %21[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %26 = llvm.getelementptr inbounds|nuw %25[%23] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %27 = llvm.load %26 : !llvm.ptr -> i32
    %28 = llvm.zext %27 : i32 to i64
    %29 = llvm.add %23, %16 : i64
    %30 = llvm.extractvalue %21[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %31 = llvm.getelementptr inbounds|nuw %30[%29] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %32 = llvm.load %31 : !llvm.ptr -> i32
    %33 = llvm.zext %32 : i32 to i64
    llvm.br ^bb3(%28 : i64)
  ^bb3(%34: i64):  // 2 preds: ^bb2, ^bb7
    %35 = llvm.icmp "slt" %34, %33 : i64
    llvm.cond_br %35, ^bb4, ^bb8
  ^bb4:  // pred: ^bb3
    %36 = llvm.extractvalue %22[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %37 = llvm.getelementptr inbounds|nuw %36[%34] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %38 = llvm.load %37 : !llvm.ptr -> i32
    %39 = llvm.zext %38 : i32 to i64
    %40 = llvm.extractvalue %20[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %41 = llvm.getelementptr inbounds|nuw %40[%34] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %42 = llvm.load %41 : !llvm.ptr -> f32
    llvm.br ^bb5(%17 : i64)
  ^bb5(%43: i64):  // 2 preds: ^bb4, ^bb6
    %44 = llvm.icmp "slt" %43, %18 : i64
    llvm.cond_br %44, ^bb6, ^bb7
  ^bb6:  // pred: ^bb5
    %45 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %46 = llvm.mlir.constant(4 : index) : i64
    %47 = llvm.mul %23, %46 overflow<nsw, nuw> : i64
    %48 = llvm.add %47, %43 overflow<nsw, nuw> : i64
    %49 = llvm.getelementptr inbounds|nuw %45[%48] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %50 = llvm.load %49 : !llvm.ptr -> f32
    %51 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %52 = llvm.mlir.constant(4 : index) : i64
    %53 = llvm.mul %39, %52 overflow<nsw, nuw> : i64
    %54 = llvm.add %53, %43 overflow<nsw, nuw> : i64
    %55 = llvm.getelementptr inbounds|nuw %51[%54] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %56 = llvm.load %55 : !llvm.ptr -> f32
    %57 = llvm.fmul %42, %56 : f32
    %58 = llvm.fadd %50, %57 : f32
    %59 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %60 = llvm.mlir.constant(4 : index) : i64
    %61 = llvm.mul %23, %60 overflow<nsw, nuw> : i64
    %62 = llvm.add %61, %43 overflow<nsw, nuw> : i64
    %63 = llvm.getelementptr inbounds|nuw %59[%62] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %58, %63 : f32, !llvm.ptr
    %64 = llvm.add %43, %16 : i64
    llvm.br ^bb5(%64 : i64)
  ^bb7:  // pred: ^bb5
    %65 = llvm.add %34, %16 : i64
    llvm.br ^bb3(%65 : i64)
  ^bb8:  // pred: ^bb3
    %66 = llvm.add %23, %16 : i64
    llvm.br ^bb1(%66 : i64)
  ^bb9:  // pred: ^bb1
    llvm.return %15 : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
  }
  llvm.func @main() {
    %0 = llvm.mlir.constant(4 : index) : i64
    %1 = llvm.mlir.zero : !llvm.ptr
    %2 = llvm.mlir.constant(0 : i32) : i32
    %3 = llvm.mlir.constant(2 : i32) : i32
    %4 = llvm.mlir.constant(262144 : i64) : i64
    %5 = llvm.mlir.constant(65536 : i64) : i64
    %6 = llvm.mlir.constant(0.000000e+00 : f32) : f32
    %7 = llvm.mlir.constant(3 : index) : i64
    %8 = llvm.mlir.constant(0 : index) : i64
    %9 = llvm.mlir.constant(5.000000e-01 : f32) : f32
    %10 = llvm.mlir.constant(10 : index) : i64
    %11 = llvm.mlir.constant(1 : index) : i64
    %12 = llvm.mlir.constant(8 : index) : i64
    %13 = llvm.mlir.constant(8 : index) : i64
    %14 = llvm.mlir.constant(4 : index) : i64
    %15 = llvm.mlir.constant(1 : index) : i64
    %16 = llvm.mlir.constant(32 : index) : i64
    %17 = llvm.mlir.zero : !llvm.ptr
    %18 = llvm.getelementptr %17[%16] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %19 = llvm.ptrtoint %18 : !llvm.ptr to i64
    %20 = llvm.mlir.addressof @__constant_8x4xf32 : !llvm.ptr
    %21 = llvm.getelementptr %20[0, 0, 0] : (!llvm.ptr) -> !llvm.ptr, !llvm.array<8 x array<4 x f32>>
    %22 = llvm.mlir.constant(3735928559 : index) : i64
    %23 = llvm.inttoptr %22 : i64 to !llvm.ptr
    %24 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %25 = llvm.insertvalue %23, %24[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %26 = llvm.insertvalue %21, %25[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %27 = llvm.mlir.constant(0 : index) : i64
    %28 = llvm.insertvalue %27, %26[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %29 = llvm.insertvalue %13, %28[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %30 = llvm.insertvalue %14, %29[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %31 = llvm.insertvalue %14, %30[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %32 = llvm.insertvalue %15, %31[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %33 = llvm.mlir.constant(8 : index) : i64
    %34 = llvm.mlir.constant(8 : index) : i64
    %35 = llvm.mlir.constant(1 : index) : i64
    %36 = llvm.mlir.constant(64 : index) : i64
    %37 = llvm.mlir.zero : !llvm.ptr
    %38 = llvm.getelementptr %37[%36] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %39 = llvm.ptrtoint %38 : !llvm.ptr to i64
    %40 = llvm.mlir.constant(64 : index) : i64
    %41 = llvm.add %39, %40 : i64
    %42 = llvm.call @malloc(%41) : (i64) -> !llvm.ptr
    %43 = llvm.ptrtoint %42 : !llvm.ptr to i64
    %44 = llvm.mlir.constant(1 : index) : i64
    %45 = llvm.sub %40, %44 : i64
    %46 = llvm.add %43, %45 : i64
    %47 = llvm.urem %46, %40 : i64
    %48 = llvm.sub %46, %47 : i64
    %49 = llvm.inttoptr %48 : i64 to !llvm.ptr
    %50 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %51 = llvm.insertvalue %42, %50[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %52 = llvm.insertvalue %49, %51[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %53 = llvm.mlir.constant(0 : index) : i64
    %54 = llvm.insertvalue %53, %52[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %55 = llvm.insertvalue %33, %54[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %56 = llvm.insertvalue %34, %55[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %57 = llvm.insertvalue %34, %56[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %58 = llvm.insertvalue %35, %57[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    llvm.br ^bb1(%8 : i64)
  ^bb1(%59: i64):  // 2 preds: ^bb0, ^bb5
    %60 = llvm.icmp "slt" %59, %12 : i64
    llvm.cond_br %60, ^bb2, ^bb6
  ^bb2:  // pred: ^bb1
    llvm.br ^bb3(%8 : i64)
  ^bb3(%61: i64):  // 2 preds: ^bb2, ^bb4
    %62 = llvm.icmp "slt" %61, %12 : i64
    llvm.cond_br %62, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %63 = llvm.add %59, %61 : i64
    %64 = llvm.uitofp %63 : i64 to f32
    %65 = llvm.urem %63, %7 : i64
    %66 = llvm.icmp "eq" %65, %8 : i64
    %67 = llvm.fmul %64, %9 : f32
    %68 = llvm.select %66, %67, %6 : i1, f32
    %69 = llvm.extractvalue %58[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %70 = llvm.mlir.constant(8 : index) : i64
    %71 = llvm.mul %59, %70 overflow<nsw, nuw> : i64
    %72 = llvm.add %71, %61 overflow<nsw, nuw> : i64
    %73 = llvm.getelementptr inbounds|nuw %69[%72] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %68, %73 : f32, !llvm.ptr
    %74 = llvm.add %61, %11 : i64
    llvm.br ^bb3(%74 : i64)
  ^bb5:  // pred: ^bb3
    %75 = llvm.add %59, %11 : i64
    llvm.br ^bb1(%75 : i64)
  ^bb6:  // pred: ^bb1
    %76 = llvm.mlir.constant(2 : index) : i64
    %77 = llvm.mlir.constant(1 : index) : i64
    %78 = llvm.alloca %76 x i64 : (i64) -> !llvm.ptr
    %79 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %80 = llvm.insertvalue %78, %79[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %81 = llvm.insertvalue %78, %80[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %82 = llvm.mlir.constant(0 : index) : i64
    %83 = llvm.insertvalue %82, %81[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %84 = llvm.insertvalue %76, %83[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %85 = llvm.insertvalue %77, %84[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %86 = llvm.extractvalue %85[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %87 = llvm.getelementptr inbounds|nuw %86[%8] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %5, %87 : i64, !llvm.ptr
    %88 = llvm.extractvalue %85[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %89 = llvm.getelementptr inbounds|nuw %88[%11] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %4, %89 : i64, !llvm.ptr
    %90 = llvm.mlir.constant(2 : index) : i64
    %91 = llvm.mlir.constant(1 : index) : i64
    %92 = llvm.alloca %90 x i64 : (i64) -> !llvm.ptr
    %93 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %94 = llvm.insertvalue %92, %93[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %95 = llvm.insertvalue %92, %94[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %96 = llvm.mlir.constant(0 : index) : i64
    %97 = llvm.insertvalue %96, %95[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %98 = llvm.insertvalue %90, %97[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %99 = llvm.insertvalue %91, %98[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %100 = llvm.extractvalue %99[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %101 = llvm.getelementptr inbounds|nuw %100[%8] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %12, %101 : i64, !llvm.ptr
    %102 = llvm.extractvalue %99[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %103 = llvm.getelementptr inbounds|nuw %102[%11] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %12, %103 : i64, !llvm.ptr
    %104 = llvm.mlir.constant(2 : index) : i64
    %105 = llvm.mlir.constant(1 : index) : i64
    %106 = llvm.alloca %104 x i64 : (i64) -> !llvm.ptr
    %107 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %108 = llvm.insertvalue %106, %107[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %109 = llvm.insertvalue %106, %108[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %110 = llvm.mlir.constant(0 : index) : i64
    %111 = llvm.insertvalue %110, %109[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %112 = llvm.insertvalue %104, %111[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %113 = llvm.insertvalue %105, %112[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %114 = llvm.extractvalue %113[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %115 = llvm.getelementptr inbounds|nuw %114[%8] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %8, %115 : i64, !llvm.ptr
    %116 = llvm.extractvalue %113[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %117 = llvm.getelementptr inbounds|nuw %116[%11] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %11, %117 : i64, !llvm.ptr
    %118 = llvm.extractvalue %99[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %119 = llvm.extractvalue %99[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %120 = llvm.extractvalue %99[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %121 = llvm.extractvalue %99[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %122 = llvm.extractvalue %99[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %123 = llvm.extractvalue %99[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %124 = llvm.extractvalue %99[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %125 = llvm.extractvalue %99[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %126 = llvm.extractvalue %99[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %127 = llvm.extractvalue %99[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %128 = llvm.extractvalue %85[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %129 = llvm.extractvalue %85[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %130 = llvm.extractvalue %85[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %131 = llvm.extractvalue %85[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %132 = llvm.extractvalue %85[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %133 = llvm.extractvalue %113[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %134 = llvm.extractvalue %113[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %135 = llvm.extractvalue %113[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %136 = llvm.extractvalue %113[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %137 = llvm.extractvalue %113[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %138 = llvm.extractvalue %113[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %139 = llvm.extractvalue %113[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %140 = llvm.extractvalue %113[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %141 = llvm.extractvalue %113[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %142 = llvm.extractvalue %113[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %143 = llvm.call @newSparseTensor(%118, %119, %120, %121, %122, %123, %124, %125, %126, %127, %128, %129, %130, %131, %132, %133, %134, %135, %136, %137, %138, %139, %140, %141, %142, %3, %3, %3, %2, %1) : (!llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, i32, i32, i32, i32, !llvm.ptr) -> !llvm.ptr
    %144 = llvm.mlir.constant(2 : index) : i64
    %145 = llvm.mlir.constant(1 : index) : i64
    %146 = llvm.alloca %144 x i64 : (i64) -> !llvm.ptr
    %147 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %148 = llvm.insertvalue %146, %147[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %149 = llvm.insertvalue %146, %148[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %150 = llvm.mlir.constant(0 : index) : i64
    %151 = llvm.insertvalue %150, %149[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %152 = llvm.insertvalue %144, %151[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %153 = llvm.insertvalue %145, %152[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %154 = llvm.mlir.constant(1 : index) : i64
    %155 = llvm.alloca %154 x f32 : (i64) -> !llvm.ptr
    %156 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64)>
    %157 = llvm.insertvalue %155, %156[0] : !llvm.struct<(ptr, ptr, i64)> 
    %158 = llvm.insertvalue %155, %157[1] : !llvm.struct<(ptr, ptr, i64)> 
    %159 = llvm.mlir.constant(0 : index) : i64
    %160 = llvm.insertvalue %159, %158[2] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.br ^bb7(%8 : i64)
  ^bb7(%161: i64):  // 2 preds: ^bb6, ^bb13
    %162 = llvm.icmp "slt" %161, %12 : i64
    llvm.cond_br %162, ^bb8, ^bb14
  ^bb8:  // pred: ^bb7
    llvm.br ^bb9(%8 : i64)
  ^bb9(%163: i64):  // 2 preds: ^bb8, ^bb12
    %164 = llvm.icmp "slt" %163, %12 : i64
    llvm.cond_br %164, ^bb10, ^bb13
  ^bb10:  // pred: ^bb9
    %165 = llvm.extractvalue %58[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %166 = llvm.mlir.constant(8 : index) : i64
    %167 = llvm.mul %161, %166 overflow<nsw, nuw> : i64
    %168 = llvm.add %167, %163 overflow<nsw, nuw> : i64
    %169 = llvm.getelementptr inbounds|nuw %165[%168] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %170 = llvm.load %169 : !llvm.ptr -> f32
    %171 = llvm.fcmp "une" %170, %6 : f32
    llvm.cond_br %171, ^bb11, ^bb12
  ^bb11:  // pred: ^bb10
    %172 = llvm.extractvalue %153[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %173 = llvm.getelementptr inbounds|nuw %172[%8] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %161, %173 : i64, !llvm.ptr
    %174 = llvm.extractvalue %153[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %175 = llvm.getelementptr inbounds|nuw %174[%11] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %163, %175 : i64, !llvm.ptr
    %176 = llvm.extractvalue %160[1] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.store %170, %176 : f32, !llvm.ptr
    %177 = llvm.extractvalue %153[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %178 = llvm.extractvalue %153[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %179 = llvm.extractvalue %153[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %180 = llvm.extractvalue %153[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %181 = llvm.extractvalue %153[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %182 = llvm.extractvalue %160[0] : !llvm.struct<(ptr, ptr, i64)> 
    %183 = llvm.extractvalue %160[1] : !llvm.struct<(ptr, ptr, i64)> 
    %184 = llvm.extractvalue %160[2] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.call @lexInsertF32(%143, %177, %178, %179, %180, %181, %182, %183, %184) : (!llvm.ptr, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64) -> ()
    llvm.br ^bb12
  ^bb12:  // 2 preds: ^bb10, ^bb11
    %185 = llvm.add %163, %11 : i64
    llvm.br ^bb9(%185 : i64)
  ^bb13:  // pred: ^bb9
    %186 = llvm.add %161, %11 : i64
    llvm.br ^bb7(%186 : i64)
  ^bb14:  // pred: ^bb7
    llvm.call @endLexInsert(%143) : (!llvm.ptr) -> ()
    %187 = llvm.mlir.constant(8 : index) : i64
    %188 = llvm.mlir.constant(4 : index) : i64
    %189 = llvm.mlir.constant(1 : index) : i64
    %190 = llvm.mlir.constant(32 : index) : i64
    %191 = llvm.mlir.zero : !llvm.ptr
    %192 = llvm.getelementptr %191[%190] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %193 = llvm.ptrtoint %192 : !llvm.ptr to i64
    %194 = llvm.mlir.constant(64 : index) : i64
    %195 = llvm.add %193, %194 : i64
    %196 = llvm.call @malloc(%195) : (i64) -> !llvm.ptr
    %197 = llvm.ptrtoint %196 : !llvm.ptr to i64
    %198 = llvm.mlir.constant(1 : index) : i64
    %199 = llvm.sub %194, %198 : i64
    %200 = llvm.add %197, %199 : i64
    %201 = llvm.urem %200, %194 : i64
    %202 = llvm.sub %200, %201 : i64
    %203 = llvm.inttoptr %202 : i64 to !llvm.ptr
    %204 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %205 = llvm.insertvalue %196, %204[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %206 = llvm.insertvalue %203, %205[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %207 = llvm.mlir.constant(0 : index) : i64
    %208 = llvm.insertvalue %207, %206[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %209 = llvm.insertvalue %187, %208[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %210 = llvm.insertvalue %188, %209[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %211 = llvm.insertvalue %188, %210[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %212 = llvm.insertvalue %189, %211[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    llvm.br ^bb15(%8 : i64)
  ^bb15(%213: i64):  // 2 preds: ^bb14, ^bb19
    %214 = llvm.icmp "slt" %213, %12 : i64
    llvm.cond_br %214, ^bb16, ^bb20
  ^bb16:  // pred: ^bb15
    llvm.br ^bb17(%8 : i64)
  ^bb17(%215: i64):  // 2 preds: ^bb16, ^bb18
    %216 = llvm.icmp "slt" %215, %0 : i64
    llvm.cond_br %216, ^bb18, ^bb19
  ^bb18:  // pred: ^bb17
    %217 = llvm.mul %213, %10 : i64
    %218 = llvm.add %217, %215 : i64
    %219 = llvm.uitofp %218 : i64 to f32
    %220 = llvm.extractvalue %212[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %221 = llvm.mlir.constant(4 : index) : i64
    %222 = llvm.mul %213, %221 overflow<nsw, nuw> : i64
    %223 = llvm.add %222, %215 overflow<nsw, nuw> : i64
    %224 = llvm.getelementptr inbounds|nuw %220[%223] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %219, %224 : f32, !llvm.ptr
    %225 = llvm.add %215, %11 : i64
    llvm.br ^bb17(%225 : i64)
  ^bb19:  // pred: ^bb17
    %226 = llvm.add %213, %11 : i64
    llvm.br ^bb15(%226 : i64)
  ^bb20:  // pred: ^bb15
    %227 = llvm.mlir.constant(8 : index) : i64
    %228 = llvm.mlir.constant(4 : index) : i64
    %229 = llvm.mlir.constant(1 : index) : i64
    %230 = llvm.mlir.constant(32 : index) : i64
    %231 = llvm.mlir.zero : !llvm.ptr
    %232 = llvm.getelementptr %231[%230] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %233 = llvm.ptrtoint %232 : !llvm.ptr to i64
    %234 = llvm.mlir.constant(64 : index) : i64
    %235 = llvm.add %233, %234 : i64
    %236 = llvm.call @malloc(%235) : (i64) -> !llvm.ptr
    %237 = llvm.ptrtoint %236 : !llvm.ptr to i64
    %238 = llvm.mlir.constant(1 : index) : i64
    %239 = llvm.sub %234, %238 : i64
    %240 = llvm.add %237, %239 : i64
    %241 = llvm.urem %240, %234 : i64
    %242 = llvm.sub %240, %241 : i64
    %243 = llvm.inttoptr %242 : i64 to !llvm.ptr
    %244 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %245 = llvm.insertvalue %236, %244[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %246 = llvm.insertvalue %243, %245[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %247 = llvm.mlir.constant(0 : index) : i64
    %248 = llvm.insertvalue %247, %246[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %249 = llvm.insertvalue %227, %248[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %250 = llvm.insertvalue %228, %249[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %251 = llvm.insertvalue %228, %250[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %252 = llvm.insertvalue %229, %251[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %253 = llvm.mlir.constant(1 : index) : i64
    %254 = llvm.extractvalue %32[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %255 = llvm.mul %253, %254 : i64
    %256 = llvm.extractvalue %32[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %257 = llvm.mul %255, %256 : i64
    %258 = llvm.mlir.zero : !llvm.ptr
    %259 = llvm.getelementptr %258[1] : (!llvm.ptr) -> !llvm.ptr, f32
    %260 = llvm.ptrtoint %259 : !llvm.ptr to i64
    %261 = llvm.mul %257, %260 : i64
    %262 = llvm.extractvalue %32[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %263 = llvm.extractvalue %32[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %264 = llvm.getelementptr %262[%263] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %265 = llvm.extractvalue %252[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %266 = llvm.extractvalue %252[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %267 = llvm.getelementptr %265[%266] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "llvm.intr.memcpy"(%267, %264, %261) <{isVolatile = false}> : (!llvm.ptr, !llvm.ptr, i64) -> ()
    %268 = llvm.extractvalue %212[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %269 = llvm.extractvalue %212[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %270 = llvm.extractvalue %212[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %271 = llvm.extractvalue %212[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %272 = llvm.extractvalue %212[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %273 = llvm.extractvalue %212[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %274 = llvm.extractvalue %212[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %275 = llvm.extractvalue %252[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %276 = llvm.extractvalue %252[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %277 = llvm.extractvalue %252[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %278 = llvm.extractvalue %252[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %279 = llvm.extractvalue %252[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %280 = llvm.extractvalue %252[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %281 = llvm.extractvalue %252[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %282 = llvm.call @weighted_spmm(%143, %268, %269, %270, %271, %272, %273, %274, %275, %276, %277, %278, %279, %280, %281) : (!llvm.ptr, !llvm.ptr, !llvm.ptr, i64, i64, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, i64, i64) -> !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %283 = llvm.mlir.constant(1 : index) : i64
    %284 = llvm.alloca %283 x !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> : (i64) -> !llvm.ptr
    llvm.store %282, %284 : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>, !llvm.ptr
    %285 = llvm.mlir.constant(2 : index) : i64
    %286 = llvm.mlir.poison : !llvm.struct<(i64, ptr)>
    %287 = llvm.insertvalue %285, %286[0] : !llvm.struct<(i64, ptr)> 
    %288 = llvm.insertvalue %284, %287[1] : !llvm.struct<(i64, ptr)> 
    %289 = llvm.extractvalue %288[0] : !llvm.struct<(i64, ptr)> 
    %290 = llvm.extractvalue %288[1] : !llvm.struct<(i64, ptr)> 
    llvm.call @printMemrefF32(%289, %290) : (i64, !llvm.ptr) -> ()
    llvm.call @delSparseTensor(%143) : (!llvm.ptr) -> ()
    llvm.return
  }
}

