module {
  llvm.func @malloc(i64) -> !llvm.ptr
  llvm.mlir.global private constant @__constant_8xf32(dense<0.000000e+00> : tensor<8xf32>) {addr_space = 0 : i32, alignment = 64 : i64} : !llvm.array<8 x f32>
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
  llvm.func @sum_per_row(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: !llvm.ptr, %arg3: i64, %arg4: i64, %arg5: i64, %arg6: !llvm.ptr, %arg7: !llvm.ptr, %arg8: i64, %arg9: i64, %arg10: i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> {
    %0 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %1 = llvm.insertvalue %arg1, %0[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %2 = llvm.insertvalue %arg2, %1[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %3 = llvm.insertvalue %arg3, %2[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %4 = llvm.insertvalue %arg4, %3[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %5 = llvm.insertvalue %arg5, %4[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %6 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %7 = llvm.insertvalue %arg6, %6[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %8 = llvm.insertvalue %arg7, %7[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %9 = llvm.insertvalue %arg8, %8[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %10 = llvm.insertvalue %arg9, %9[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %11 = llvm.insertvalue %arg10, %10[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %12 = llvm.mlir.constant(1 : index) : i64
    %13 = llvm.mlir.constant(0 : index) : i64
    %14 = llvm.mlir.constant(8 : index) : i64
    %15 = llvm.call @sparseValuesF32(%arg0) : (!llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %16 = llvm.call @sparsePositions32(%arg0, %12) : (!llvm.ptr, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %17 = llvm.call @sparseCoordinates32(%arg0, %12) : (!llvm.ptr, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.br ^bb1(%13 : i64)
  ^bb1(%18: i64):  // 2 preds: ^bb0, ^bb5
    %19 = llvm.icmp "slt" %18, %14 : i64
    llvm.cond_br %19, ^bb2, ^bb6
  ^bb2:  // pred: ^bb1
    %20 = llvm.extractvalue %11[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %21 = llvm.getelementptr inbounds|nuw %20[%18] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %22 = llvm.load %21 : !llvm.ptr -> f32
    %23 = llvm.extractvalue %16[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %24 = llvm.getelementptr inbounds|nuw %23[%18] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %25 = llvm.load %24 : !llvm.ptr -> i32
    %26 = llvm.zext %25 : i32 to i64
    %27 = llvm.add %18, %12 : i64
    %28 = llvm.extractvalue %16[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %29 = llvm.getelementptr inbounds|nuw %28[%27] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %30 = llvm.load %29 : !llvm.ptr -> i32
    %31 = llvm.zext %30 : i32 to i64
    llvm.br ^bb3(%26, %22 : i64, f32)
  ^bb3(%32: i64, %33: f32):  // 2 preds: ^bb2, ^bb4
    %34 = llvm.icmp "slt" %32, %31 : i64
    llvm.cond_br %34, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %35 = llvm.extractvalue %17[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %36 = llvm.getelementptr inbounds|nuw %35[%32] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %37 = llvm.load %36 : !llvm.ptr -> i32
    %38 = llvm.zext %37 : i32 to i64
    %39 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %40 = llvm.getelementptr inbounds|nuw %39[%32] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %41 = llvm.load %40 : !llvm.ptr -> f32
    %42 = llvm.extractvalue %5[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %43 = llvm.getelementptr inbounds|nuw %42[%38] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %44 = llvm.load %43 : !llvm.ptr -> f32
    %45 = llvm.fmul %41, %44 : f32
    %46 = llvm.fadd %33, %45 : f32
    %47 = llvm.add %32, %12 : i64
    llvm.br ^bb3(%47, %46 : i64, f32)
  ^bb5:  // pred: ^bb3
    %48 = llvm.extractvalue %11[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %49 = llvm.getelementptr inbounds|nuw %48[%18] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %33, %49 : f32, !llvm.ptr
    %50 = llvm.add %18, %12 : i64
    llvm.br ^bb1(%50 : i64)
  ^bb6:  // pred: ^bb1
    llvm.return %11 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  }
  llvm.func @main() {
    %0 = llvm.mlir.zero : !llvm.ptr
    %1 = llvm.mlir.constant(0 : i32) : i32
    %2 = llvm.mlir.constant(2 : i32) : i32
    %3 = llvm.mlir.constant(262144 : i64) : i64
    %4 = llvm.mlir.constant(65536 : i64) : i64
    %5 = llvm.mlir.constant(0.000000e+00 : f32) : f32
    %6 = llvm.mlir.constant(3 : index) : i64
    %7 = llvm.mlir.constant(0 : index) : i64
    %8 = llvm.mlir.constant(1.000000e+00 : f32) : f32
    %9 = llvm.mlir.constant(1 : index) : i64
    %10 = llvm.mlir.constant(8 : index) : i64
    %11 = llvm.mlir.constant(8 : index) : i64
    %12 = llvm.mlir.constant(1 : index) : i64
    %13 = llvm.mlir.zero : !llvm.ptr
    %14 = llvm.getelementptr %13[%11] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %15 = llvm.ptrtoint %14 : !llvm.ptr to i64
    %16 = llvm.mlir.addressof @__constant_8xf32 : !llvm.ptr
    %17 = llvm.getelementptr %16[0, 0] : (!llvm.ptr) -> !llvm.ptr, !llvm.array<8 x f32>
    %18 = llvm.mlir.constant(3735928559 : index) : i64
    %19 = llvm.inttoptr %18 : i64 to !llvm.ptr
    %20 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %21 = llvm.insertvalue %19, %20[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %22 = llvm.insertvalue %17, %21[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %23 = llvm.mlir.constant(0 : index) : i64
    %24 = llvm.insertvalue %23, %22[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %25 = llvm.insertvalue %11, %24[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %26 = llvm.insertvalue %12, %25[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %27 = llvm.mlir.constant(8 : index) : i64
    %28 = llvm.mlir.constant(8 : index) : i64
    %29 = llvm.mlir.constant(1 : index) : i64
    %30 = llvm.mlir.constant(64 : index) : i64
    %31 = llvm.mlir.zero : !llvm.ptr
    %32 = llvm.getelementptr %31[%30] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %33 = llvm.ptrtoint %32 : !llvm.ptr to i64
    %34 = llvm.mlir.constant(64 : index) : i64
    %35 = llvm.add %33, %34 : i64
    %36 = llvm.call @malloc(%35) : (i64) -> !llvm.ptr
    %37 = llvm.ptrtoint %36 : !llvm.ptr to i64
    %38 = llvm.mlir.constant(1 : index) : i64
    %39 = llvm.sub %34, %38 : i64
    %40 = llvm.add %37, %39 : i64
    %41 = llvm.urem %40, %34 : i64
    %42 = llvm.sub %40, %41 : i64
    %43 = llvm.inttoptr %42 : i64 to !llvm.ptr
    %44 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %45 = llvm.insertvalue %36, %44[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %46 = llvm.insertvalue %43, %45[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %47 = llvm.mlir.constant(0 : index) : i64
    %48 = llvm.insertvalue %47, %46[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %49 = llvm.insertvalue %27, %48[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %50 = llvm.insertvalue %28, %49[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %51 = llvm.insertvalue %28, %50[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %52 = llvm.insertvalue %29, %51[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    llvm.br ^bb1(%7 : i64)
  ^bb1(%53: i64):  // 2 preds: ^bb0, ^bb5
    %54 = llvm.icmp "slt" %53, %10 : i64
    llvm.cond_br %54, ^bb2, ^bb6
  ^bb2:  // pred: ^bb1
    llvm.br ^bb3(%7 : i64)
  ^bb3(%55: i64):  // 2 preds: ^bb2, ^bb4
    %56 = llvm.icmp "slt" %55, %10 : i64
    llvm.cond_br %56, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %57 = llvm.add %53, %55 : i64
    %58 = llvm.uitofp %57 : i64 to f32
    %59 = llvm.urem %57, %6 : i64
    %60 = llvm.icmp "eq" %59, %7 : i64
    %61 = llvm.select %60, %58, %5 : i1, f32
    %62 = llvm.extractvalue %52[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %63 = llvm.mlir.constant(8 : index) : i64
    %64 = llvm.mul %53, %63 overflow<nsw, nuw> : i64
    %65 = llvm.add %64, %55 overflow<nsw, nuw> : i64
    %66 = llvm.getelementptr inbounds|nuw %62[%65] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %61, %66 : f32, !llvm.ptr
    %67 = llvm.add %55, %9 : i64
    llvm.br ^bb3(%67 : i64)
  ^bb5:  // pred: ^bb3
    %68 = llvm.add %53, %9 : i64
    llvm.br ^bb1(%68 : i64)
  ^bb6:  // pred: ^bb1
    %69 = llvm.mlir.constant(2 : index) : i64
    %70 = llvm.mlir.constant(1 : index) : i64
    %71 = llvm.alloca %69 x i64 : (i64) -> !llvm.ptr
    %72 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %73 = llvm.insertvalue %71, %72[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %74 = llvm.insertvalue %71, %73[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %75 = llvm.mlir.constant(0 : index) : i64
    %76 = llvm.insertvalue %75, %74[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %77 = llvm.insertvalue %69, %76[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %78 = llvm.insertvalue %70, %77[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %79 = llvm.extractvalue %78[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %80 = llvm.getelementptr inbounds|nuw %79[%7] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %4, %80 : i64, !llvm.ptr
    %81 = llvm.extractvalue %78[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %82 = llvm.getelementptr inbounds|nuw %81[%9] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %3, %82 : i64, !llvm.ptr
    %83 = llvm.mlir.constant(2 : index) : i64
    %84 = llvm.mlir.constant(1 : index) : i64
    %85 = llvm.alloca %83 x i64 : (i64) -> !llvm.ptr
    %86 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %87 = llvm.insertvalue %85, %86[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %88 = llvm.insertvalue %85, %87[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %89 = llvm.mlir.constant(0 : index) : i64
    %90 = llvm.insertvalue %89, %88[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %91 = llvm.insertvalue %83, %90[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %92 = llvm.insertvalue %84, %91[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %93 = llvm.extractvalue %92[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %94 = llvm.getelementptr inbounds|nuw %93[%7] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %10, %94 : i64, !llvm.ptr
    %95 = llvm.extractvalue %92[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %96 = llvm.getelementptr inbounds|nuw %95[%9] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %10, %96 : i64, !llvm.ptr
    %97 = llvm.mlir.constant(2 : index) : i64
    %98 = llvm.mlir.constant(1 : index) : i64
    %99 = llvm.alloca %97 x i64 : (i64) -> !llvm.ptr
    %100 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %101 = llvm.insertvalue %99, %100[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %102 = llvm.insertvalue %99, %101[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %103 = llvm.mlir.constant(0 : index) : i64
    %104 = llvm.insertvalue %103, %102[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %105 = llvm.insertvalue %97, %104[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %106 = llvm.insertvalue %98, %105[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %107 = llvm.extractvalue %106[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %108 = llvm.getelementptr inbounds|nuw %107[%7] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %7, %108 : i64, !llvm.ptr
    %109 = llvm.extractvalue %106[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %110 = llvm.getelementptr inbounds|nuw %109[%9] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %9, %110 : i64, !llvm.ptr
    %111 = llvm.extractvalue %92[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %112 = llvm.extractvalue %92[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %113 = llvm.extractvalue %92[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %114 = llvm.extractvalue %92[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %115 = llvm.extractvalue %92[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %116 = llvm.extractvalue %92[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %117 = llvm.extractvalue %92[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %118 = llvm.extractvalue %92[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %119 = llvm.extractvalue %92[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %120 = llvm.extractvalue %92[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %121 = llvm.extractvalue %78[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %122 = llvm.extractvalue %78[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %123 = llvm.extractvalue %78[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %124 = llvm.extractvalue %78[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %125 = llvm.extractvalue %78[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %126 = llvm.extractvalue %106[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %127 = llvm.extractvalue %106[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %128 = llvm.extractvalue %106[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %129 = llvm.extractvalue %106[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %130 = llvm.extractvalue %106[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %131 = llvm.extractvalue %106[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %132 = llvm.extractvalue %106[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %133 = llvm.extractvalue %106[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %134 = llvm.extractvalue %106[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %135 = llvm.extractvalue %106[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %136 = llvm.call @newSparseTensor(%111, %112, %113, %114, %115, %116, %117, %118, %119, %120, %121, %122, %123, %124, %125, %126, %127, %128, %129, %130, %131, %132, %133, %134, %135, %2, %2, %2, %1, %0) : (!llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, i32, i32, i32, i32, !llvm.ptr) -> !llvm.ptr
    %137 = llvm.mlir.constant(2 : index) : i64
    %138 = llvm.mlir.constant(1 : index) : i64
    %139 = llvm.alloca %137 x i64 : (i64) -> !llvm.ptr
    %140 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %141 = llvm.insertvalue %139, %140[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %142 = llvm.insertvalue %139, %141[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %143 = llvm.mlir.constant(0 : index) : i64
    %144 = llvm.insertvalue %143, %142[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %145 = llvm.insertvalue %137, %144[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %146 = llvm.insertvalue %138, %145[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %147 = llvm.mlir.constant(1 : index) : i64
    %148 = llvm.alloca %147 x f32 : (i64) -> !llvm.ptr
    %149 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64)>
    %150 = llvm.insertvalue %148, %149[0] : !llvm.struct<(ptr, ptr, i64)> 
    %151 = llvm.insertvalue %148, %150[1] : !llvm.struct<(ptr, ptr, i64)> 
    %152 = llvm.mlir.constant(0 : index) : i64
    %153 = llvm.insertvalue %152, %151[2] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.br ^bb7(%7 : i64)
  ^bb7(%154: i64):  // 2 preds: ^bb6, ^bb13
    %155 = llvm.icmp "slt" %154, %10 : i64
    llvm.cond_br %155, ^bb8, ^bb14
  ^bb8:  // pred: ^bb7
    llvm.br ^bb9(%7 : i64)
  ^bb9(%156: i64):  // 2 preds: ^bb8, ^bb12
    %157 = llvm.icmp "slt" %156, %10 : i64
    llvm.cond_br %157, ^bb10, ^bb13
  ^bb10:  // pred: ^bb9
    %158 = llvm.extractvalue %52[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %159 = llvm.mlir.constant(8 : index) : i64
    %160 = llvm.mul %154, %159 overflow<nsw, nuw> : i64
    %161 = llvm.add %160, %156 overflow<nsw, nuw> : i64
    %162 = llvm.getelementptr inbounds|nuw %158[%161] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %163 = llvm.load %162 : !llvm.ptr -> f32
    %164 = llvm.fcmp "une" %163, %5 : f32
    llvm.cond_br %164, ^bb11, ^bb12
  ^bb11:  // pred: ^bb10
    %165 = llvm.extractvalue %146[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %166 = llvm.getelementptr inbounds|nuw %165[%7] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %154, %166 : i64, !llvm.ptr
    %167 = llvm.extractvalue %146[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %168 = llvm.getelementptr inbounds|nuw %167[%9] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %156, %168 : i64, !llvm.ptr
    %169 = llvm.extractvalue %153[1] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.store %163, %169 : f32, !llvm.ptr
    %170 = llvm.extractvalue %146[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %171 = llvm.extractvalue %146[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %172 = llvm.extractvalue %146[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %173 = llvm.extractvalue %146[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %174 = llvm.extractvalue %146[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %175 = llvm.extractvalue %153[0] : !llvm.struct<(ptr, ptr, i64)> 
    %176 = llvm.extractvalue %153[1] : !llvm.struct<(ptr, ptr, i64)> 
    %177 = llvm.extractvalue %153[2] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.call @lexInsertF32(%136, %170, %171, %172, %173, %174, %175, %176, %177) : (!llvm.ptr, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64) -> ()
    llvm.br ^bb12
  ^bb12:  // 2 preds: ^bb10, ^bb11
    %178 = llvm.add %156, %9 : i64
    llvm.br ^bb9(%178 : i64)
  ^bb13:  // pred: ^bb9
    %179 = llvm.add %154, %9 : i64
    llvm.br ^bb7(%179 : i64)
  ^bb14:  // pred: ^bb7
    llvm.call @endLexInsert(%136) : (!llvm.ptr) -> ()
    %180 = llvm.mlir.constant(8 : index) : i64
    %181 = llvm.mlir.constant(1 : index) : i64
    %182 = llvm.mlir.zero : !llvm.ptr
    %183 = llvm.getelementptr %182[%180] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %184 = llvm.ptrtoint %183 : !llvm.ptr to i64
    %185 = llvm.mlir.constant(64 : index) : i64
    %186 = llvm.add %184, %185 : i64
    %187 = llvm.call @malloc(%186) : (i64) -> !llvm.ptr
    %188 = llvm.ptrtoint %187 : !llvm.ptr to i64
    %189 = llvm.mlir.constant(1 : index) : i64
    %190 = llvm.sub %185, %189 : i64
    %191 = llvm.add %188, %190 : i64
    %192 = llvm.urem %191, %185 : i64
    %193 = llvm.sub %191, %192 : i64
    %194 = llvm.inttoptr %193 : i64 to !llvm.ptr
    %195 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %196 = llvm.insertvalue %187, %195[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %197 = llvm.insertvalue %194, %196[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %198 = llvm.mlir.constant(0 : index) : i64
    %199 = llvm.insertvalue %198, %197[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %200 = llvm.insertvalue %180, %199[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %201 = llvm.insertvalue %181, %200[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    llvm.br ^bb15(%7 : i64)
  ^bb15(%202: i64):  // 2 preds: ^bb14, ^bb16
    %203 = llvm.icmp "slt" %202, %10 : i64
    llvm.cond_br %203, ^bb16, ^bb17
  ^bb16:  // pred: ^bb15
    %204 = llvm.extractvalue %201[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %205 = llvm.getelementptr inbounds|nuw %204[%202] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %8, %205 : f32, !llvm.ptr
    %206 = llvm.add %202, %9 : i64
    llvm.br ^bb15(%206 : i64)
  ^bb17:  // pred: ^bb15
    %207 = llvm.mlir.constant(8 : index) : i64
    %208 = llvm.mlir.constant(1 : index) : i64
    %209 = llvm.mlir.zero : !llvm.ptr
    %210 = llvm.getelementptr %209[%207] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %211 = llvm.ptrtoint %210 : !llvm.ptr to i64
    %212 = llvm.mlir.constant(64 : index) : i64
    %213 = llvm.add %211, %212 : i64
    %214 = llvm.call @malloc(%213) : (i64) -> !llvm.ptr
    %215 = llvm.ptrtoint %214 : !llvm.ptr to i64
    %216 = llvm.mlir.constant(1 : index) : i64
    %217 = llvm.sub %212, %216 : i64
    %218 = llvm.add %215, %217 : i64
    %219 = llvm.urem %218, %212 : i64
    %220 = llvm.sub %218, %219 : i64
    %221 = llvm.inttoptr %220 : i64 to !llvm.ptr
    %222 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %223 = llvm.insertvalue %214, %222[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %224 = llvm.insertvalue %221, %223[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %225 = llvm.mlir.constant(0 : index) : i64
    %226 = llvm.insertvalue %225, %224[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %227 = llvm.insertvalue %207, %226[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %228 = llvm.insertvalue %208, %227[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %229 = llvm.mlir.constant(1 : index) : i64
    %230 = llvm.extractvalue %26[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %231 = llvm.mul %229, %230 : i64
    %232 = llvm.mlir.zero : !llvm.ptr
    %233 = llvm.getelementptr %232[1] : (!llvm.ptr) -> !llvm.ptr, f32
    %234 = llvm.ptrtoint %233 : !llvm.ptr to i64
    %235 = llvm.mul %231, %234 : i64
    %236 = llvm.extractvalue %26[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %237 = llvm.extractvalue %26[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %238 = llvm.getelementptr %236[%237] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %239 = llvm.extractvalue %228[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %240 = llvm.extractvalue %228[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %241 = llvm.getelementptr %239[%240] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "llvm.intr.memcpy"(%241, %238, %235) <{isVolatile = false}> : (!llvm.ptr, !llvm.ptr, i64) -> ()
    %242 = llvm.extractvalue %201[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %243 = llvm.extractvalue %201[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %244 = llvm.extractvalue %201[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %245 = llvm.extractvalue %201[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %246 = llvm.extractvalue %201[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %247 = llvm.extractvalue %228[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %248 = llvm.extractvalue %228[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %249 = llvm.extractvalue %228[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %250 = llvm.extractvalue %228[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %251 = llvm.extractvalue %228[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %252 = llvm.call @sum_per_row(%136, %242, %243, %244, %245, %246, %247, %248, %249, %250, %251) : (!llvm.ptr, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %253 = llvm.mlir.constant(1 : index) : i64
    %254 = llvm.alloca %253 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.store %252, %254 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>, !llvm.ptr
    %255 = llvm.mlir.constant(1 : index) : i64
    %256 = llvm.mlir.poison : !llvm.struct<(i64, ptr)>
    %257 = llvm.insertvalue %255, %256[0] : !llvm.struct<(i64, ptr)> 
    %258 = llvm.insertvalue %254, %257[1] : !llvm.struct<(i64, ptr)> 
    %259 = llvm.extractvalue %258[0] : !llvm.struct<(i64, ptr)> 
    %260 = llvm.extractvalue %258[1] : !llvm.struct<(i64, ptr)> 
    llvm.call @printMemrefF32(%259, %260) : (i64, !llvm.ptr) -> ()
    llvm.call @delSparseTensor(%136) : (!llvm.ptr) -> ()
    llvm.return
  }
}

