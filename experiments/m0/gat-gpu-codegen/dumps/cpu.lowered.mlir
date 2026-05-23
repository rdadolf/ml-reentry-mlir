module {
  llvm.func @malloc(i64) -> !llvm.ptr
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
  llvm.func private @sparseCoordinates64(%arg0: !llvm.ptr, %arg1: i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> attributes {llvm.emit_c_interface, sym_visibility = "private"} {
    %0 = llvm.mlir.constant(1 : index) : i64
    %1 = llvm.alloca %0 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.call @_mlir_ciface_sparseCoordinates64(%1, %arg0, %arg1) : (!llvm.ptr, !llvm.ptr, i64) -> ()
    %2 = llvm.load %1 : !llvm.ptr -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.return %2 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  }
  llvm.func @_mlir_ciface_sparseCoordinates64(!llvm.ptr, !llvm.ptr, i64) attributes {llvm.emit_c_interface, sym_visibility = "private"}
  llvm.func private @sparsePositions64(%arg0: !llvm.ptr, %arg1: i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> attributes {llvm.emit_c_interface, sym_visibility = "private"} {
    %0 = llvm.mlir.constant(1 : index) : i64
    %1 = llvm.alloca %0 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.call @_mlir_ciface_sparsePositions64(%1, %arg0, %arg1) : (!llvm.ptr, !llvm.ptr, i64) -> ()
    %2 = llvm.load %1 : !llvm.ptr -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.return %2 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  }
  llvm.func @_mlir_ciface_sparsePositions64(!llvm.ptr, !llvm.ptr, i64) attributes {llvm.emit_c_interface, sym_visibility = "private"}
  llvm.func private @sparseValuesF32(%arg0: !llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> attributes {llvm.emit_c_interface, sym_visibility = "private"} {
    %0 = llvm.mlir.constant(1 : index) : i64
    %1 = llvm.alloca %0 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.call @_mlir_ciface_sparseValuesF32(%1, %arg0) : (!llvm.ptr, !llvm.ptr) -> ()
    %2 = llvm.load %1 : !llvm.ptr -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.return %2 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  }
  llvm.func @_mlir_ciface_sparseValuesF32(!llvm.ptr, !llvm.ptr) attributes {llvm.emit_c_interface, sym_visibility = "private"}
  llvm.func @printMemrefF32(i64, !llvm.ptr) attributes {sym_visibility = "private"}
  llvm.func @row_max(%arg0: !llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> {
    %0 = llvm.mlir.constant(1 : index) : i64
    %1 = llvm.mlir.constant(0 : index) : i64
    %2 = llvm.mlir.constant(64 : index) : i64
    %3 = llvm.mlir.constant(0xFF800000 : f32) : f32
    %4 = llvm.mlir.constant(64 : index) : i64
    %5 = llvm.mlir.constant(1 : index) : i64
    %6 = llvm.mlir.zero : !llvm.ptr
    %7 = llvm.getelementptr %6[%4] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %8 = llvm.ptrtoint %7 : !llvm.ptr to i64
    %9 = llvm.mlir.constant(64 : index) : i64
    %10 = llvm.add %8, %9 : i64
    %11 = llvm.call @malloc(%10) : (i64) -> !llvm.ptr
    %12 = llvm.ptrtoint %11 : !llvm.ptr to i64
    %13 = llvm.mlir.constant(1 : index) : i64
    %14 = llvm.sub %9, %13 : i64
    %15 = llvm.add %12, %14 : i64
    %16 = llvm.urem %15, %9 : i64
    %17 = llvm.sub %15, %16 : i64
    %18 = llvm.inttoptr %17 : i64 to !llvm.ptr
    %19 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %20 = llvm.insertvalue %11, %19[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %21 = llvm.insertvalue %18, %20[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %22 = llvm.mlir.constant(0 : index) : i64
    %23 = llvm.insertvalue %22, %21[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %24 = llvm.insertvalue %4, %23[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %25 = llvm.insertvalue %5, %24[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    llvm.br ^bb1(%1 : i64)
  ^bb1(%26: i64):  // 2 preds: ^bb0, ^bb2
    %27 = llvm.icmp "slt" %26, %2 : i64
    llvm.cond_br %27, ^bb2, ^bb3
  ^bb2:  // pred: ^bb1
    %28 = llvm.extractvalue %25[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %29 = llvm.getelementptr inbounds|nuw %28[%26] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %3, %29 : f32, !llvm.ptr
    %30 = llvm.add %26, %0 : i64
    llvm.br ^bb1(%30 : i64)
  ^bb3:  // pred: ^bb1
    %31 = llvm.call @sparseValuesF32(%arg0) : (!llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %32 = llvm.call @sparsePositions64(%arg0, %0) : (!llvm.ptr, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.br ^bb4(%1 : i64)
  ^bb4(%33: i64):  // 2 preds: ^bb3, ^bb8
    %34 = llvm.icmp "slt" %33, %2 : i64
    llvm.cond_br %34, ^bb5, ^bb9
  ^bb5:  // pred: ^bb4
    %35 = llvm.extractvalue %32[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %36 = llvm.getelementptr inbounds|nuw %35[%33] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    %37 = llvm.load %36 : !llvm.ptr -> i64
    %38 = llvm.add %33, %0 : i64
    %39 = llvm.extractvalue %32[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %40 = llvm.getelementptr inbounds|nuw %39[%38] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    %41 = llvm.load %40 : !llvm.ptr -> i64
    llvm.br ^bb6(%37, %3 : i64, f32)
  ^bb6(%42: i64, %43: f32):  // 2 preds: ^bb5, ^bb7
    %44 = llvm.icmp "slt" %42, %41 : i64
    llvm.cond_br %44, ^bb7, ^bb8
  ^bb7:  // pred: ^bb6
    %45 = llvm.extractvalue %31[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %46 = llvm.getelementptr inbounds|nuw %45[%42] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %47 = llvm.load %46 : !llvm.ptr -> f32
    %48 = llvm.fcmp "ugt" %47, %43 : f32
    %49 = llvm.select %48, %47, %43 : i1, f32
    %50 = llvm.fcmp "uno" %43, %43 : f32
    %51 = llvm.select %50, %43, %49 : i1, f32
    %52 = llvm.add %42, %0 : i64
    llvm.br ^bb6(%52, %51 : i64, f32)
  ^bb8:  // pred: ^bb6
    %53 = llvm.extractvalue %25[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %54 = llvm.getelementptr inbounds|nuw %53[%33] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %43, %54 : f32, !llvm.ptr
    %55 = llvm.add %33, %0 : i64
    llvm.br ^bb4(%55 : i64)
  ^bb9:  // pred: ^bb4
    llvm.return %25 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  }
  llvm.func @row_expsum(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: !llvm.ptr, %arg3: i64, %arg4: i64, %arg5: i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> {
    %0 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %1 = llvm.insertvalue %arg1, %0[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %2 = llvm.insertvalue %arg2, %1[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %3 = llvm.insertvalue %arg3, %2[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %4 = llvm.insertvalue %arg4, %3[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %5 = llvm.insertvalue %arg5, %4[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %6 = llvm.mlir.constant(1 : index) : i64
    %7 = llvm.mlir.constant(0 : index) : i64
    %8 = llvm.mlir.constant(64 : index) : i64
    %9 = llvm.mlir.constant(0.000000e+00 : f32) : f32
    %10 = llvm.mlir.constant(64 : index) : i64
    %11 = llvm.mlir.constant(1 : index) : i64
    %12 = llvm.mlir.zero : !llvm.ptr
    %13 = llvm.getelementptr %12[%10] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %14 = llvm.ptrtoint %13 : !llvm.ptr to i64
    %15 = llvm.mlir.constant(64 : index) : i64
    %16 = llvm.add %14, %15 : i64
    %17 = llvm.call @malloc(%16) : (i64) -> !llvm.ptr
    %18 = llvm.ptrtoint %17 : !llvm.ptr to i64
    %19 = llvm.mlir.constant(1 : index) : i64
    %20 = llvm.sub %15, %19 : i64
    %21 = llvm.add %18, %20 : i64
    %22 = llvm.urem %21, %15 : i64
    %23 = llvm.sub %21, %22 : i64
    %24 = llvm.inttoptr %23 : i64 to !llvm.ptr
    %25 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %26 = llvm.insertvalue %17, %25[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %27 = llvm.insertvalue %24, %26[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %28 = llvm.mlir.constant(0 : index) : i64
    %29 = llvm.insertvalue %28, %27[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %30 = llvm.insertvalue %10, %29[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %31 = llvm.insertvalue %11, %30[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    llvm.br ^bb1(%7 : i64)
  ^bb1(%32: i64):  // 2 preds: ^bb0, ^bb2
    %33 = llvm.icmp "slt" %32, %8 : i64
    llvm.cond_br %33, ^bb2, ^bb3
  ^bb2:  // pred: ^bb1
    %34 = llvm.extractvalue %31[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %35 = llvm.getelementptr inbounds|nuw %34[%32] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %9, %35 : f32, !llvm.ptr
    %36 = llvm.add %32, %6 : i64
    llvm.br ^bb1(%36 : i64)
  ^bb3:  // pred: ^bb1
    %37 = llvm.call @sparseValuesF32(%arg0) : (!llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %38 = llvm.call @sparsePositions64(%arg0, %6) : (!llvm.ptr, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.br ^bb4(%7 : i64)
  ^bb4(%39: i64):  // 2 preds: ^bb3, ^bb8
    %40 = llvm.icmp "slt" %39, %8 : i64
    llvm.cond_br %40, ^bb5, ^bb9
  ^bb5:  // pred: ^bb4
    %41 = llvm.extractvalue %38[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %42 = llvm.getelementptr inbounds|nuw %41[%39] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    %43 = llvm.load %42 : !llvm.ptr -> i64
    %44 = llvm.add %39, %6 : i64
    %45 = llvm.extractvalue %38[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %46 = llvm.getelementptr inbounds|nuw %45[%44] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    %47 = llvm.load %46 : !llvm.ptr -> i64
    llvm.br ^bb6(%43, %9 : i64, f32)
  ^bb6(%48: i64, %49: f32):  // 2 preds: ^bb5, ^bb7
    %50 = llvm.icmp "slt" %48, %47 : i64
    llvm.cond_br %50, ^bb7, ^bb8
  ^bb7:  // pred: ^bb6
    %51 = llvm.extractvalue %5[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %52 = llvm.getelementptr inbounds|nuw %51[%39] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %53 = llvm.load %52 : !llvm.ptr -> f32
    %54 = llvm.extractvalue %37[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %55 = llvm.getelementptr inbounds|nuw %54[%48] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %56 = llvm.load %55 : !llvm.ptr -> f32
    %57 = llvm.fsub %56, %53 : f32
    %58 = llvm.intr.exp(%57) : (f32) -> f32
    %59 = llvm.fadd %49, %58 : f32
    %60 = llvm.add %48, %6 : i64
    llvm.br ^bb6(%60, %59 : i64, f32)
  ^bb8:  // pred: ^bb6
    %61 = llvm.extractvalue %31[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %62 = llvm.getelementptr inbounds|nuw %61[%39] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %49, %62 : f32, !llvm.ptr
    %63 = llvm.add %39, %6 : i64
    llvm.br ^bb4(%63 : i64)
  ^bb9:  // pred: ^bb4
    llvm.return %31 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  }
  llvm.func @weighted_aggregate(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: !llvm.ptr, %arg3: i64, %arg4: i64, %arg5: i64, %arg6: !llvm.ptr, %arg7: !llvm.ptr, %arg8: i64, %arg9: i64, %arg10: i64, %arg11: !llvm.ptr, %arg12: !llvm.ptr, %arg13: i64, %arg14: i64, %arg15: i64, %arg16: i64, %arg17: i64) -> !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> {
    %0 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %1 = llvm.insertvalue %arg11, %0[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %2 = llvm.insertvalue %arg12, %1[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %3 = llvm.insertvalue %arg13, %2[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %4 = llvm.insertvalue %arg14, %3[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %5 = llvm.insertvalue %arg16, %4[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %6 = llvm.insertvalue %arg15, %5[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %7 = llvm.insertvalue %arg17, %6[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %8 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %9 = llvm.insertvalue %arg6, %8[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %10 = llvm.insertvalue %arg7, %9[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %11 = llvm.insertvalue %arg8, %10[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %12 = llvm.insertvalue %arg9, %11[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %13 = llvm.insertvalue %arg10, %12[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %14 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %15 = llvm.insertvalue %arg1, %14[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %16 = llvm.insertvalue %arg2, %15[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %17 = llvm.insertvalue %arg3, %16[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %18 = llvm.insertvalue %arg4, %17[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %19 = llvm.insertvalue %arg5, %18[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %20 = llvm.mlir.constant(1 : index) : i64
    %21 = llvm.mlir.constant(0 : index) : i64
    %22 = llvm.mlir.constant(32 : index) : i64
    %23 = llvm.mlir.constant(64 : index) : i64
    %24 = llvm.mlir.constant(0.000000e+00 : f32) : f32
    %25 = llvm.mlir.constant(64 : index) : i64
    %26 = llvm.mlir.constant(32 : index) : i64
    %27 = llvm.mlir.constant(1 : index) : i64
    %28 = llvm.mlir.constant(2048 : index) : i64
    %29 = llvm.mlir.zero : !llvm.ptr
    %30 = llvm.getelementptr %29[%28] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %31 = llvm.ptrtoint %30 : !llvm.ptr to i64
    %32 = llvm.mlir.constant(64 : index) : i64
    %33 = llvm.add %31, %32 : i64
    %34 = llvm.call @malloc(%33) : (i64) -> !llvm.ptr
    %35 = llvm.ptrtoint %34 : !llvm.ptr to i64
    %36 = llvm.mlir.constant(1 : index) : i64
    %37 = llvm.sub %32, %36 : i64
    %38 = llvm.add %35, %37 : i64
    %39 = llvm.urem %38, %32 : i64
    %40 = llvm.sub %38, %39 : i64
    %41 = llvm.inttoptr %40 : i64 to !llvm.ptr
    %42 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %43 = llvm.insertvalue %34, %42[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %44 = llvm.insertvalue %41, %43[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %45 = llvm.mlir.constant(0 : index) : i64
    %46 = llvm.insertvalue %45, %44[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %47 = llvm.insertvalue %25, %46[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %48 = llvm.insertvalue %26, %47[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %49 = llvm.insertvalue %26, %48[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %50 = llvm.insertvalue %27, %49[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    llvm.br ^bb1(%21 : i64)
  ^bb1(%51: i64):  // 2 preds: ^bb0, ^bb5
    %52 = llvm.icmp "slt" %51, %23 : i64
    llvm.cond_br %52, ^bb2, ^bb6
  ^bb2:  // pred: ^bb1
    llvm.br ^bb3(%21 : i64)
  ^bb3(%53: i64):  // 2 preds: ^bb2, ^bb4
    %54 = llvm.icmp "slt" %53, %22 : i64
    llvm.cond_br %54, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %55 = llvm.extractvalue %50[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %56 = llvm.mlir.constant(32 : index) : i64
    %57 = llvm.mul %51, %56 overflow<nsw, nuw> : i64
    %58 = llvm.add %57, %53 overflow<nsw, nuw> : i64
    %59 = llvm.getelementptr inbounds|nuw %55[%58] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %24, %59 : f32, !llvm.ptr
    %60 = llvm.add %53, %20 : i64
    llvm.br ^bb3(%60 : i64)
  ^bb5:  // pred: ^bb3
    %61 = llvm.add %51, %20 : i64
    llvm.br ^bb1(%61 : i64)
  ^bb6:  // pred: ^bb1
    %62 = llvm.call @sparseValuesF32(%arg0) : (!llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %63 = llvm.call @sparsePositions64(%arg0, %20) : (!llvm.ptr, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %64 = llvm.call @sparseCoordinates64(%arg0, %20) : (!llvm.ptr, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.br ^bb7(%21 : i64)
  ^bb7(%65: i64):  // 2 preds: ^bb6, ^bb14
    %66 = llvm.icmp "slt" %65, %23 : i64
    llvm.cond_br %66, ^bb8, ^bb15
  ^bb8:  // pred: ^bb7
    %67 = llvm.extractvalue %63[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %68 = llvm.getelementptr inbounds|nuw %67[%65] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    %69 = llvm.load %68 : !llvm.ptr -> i64
    %70 = llvm.add %65, %20 : i64
    %71 = llvm.extractvalue %63[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %72 = llvm.getelementptr inbounds|nuw %71[%70] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    %73 = llvm.load %72 : !llvm.ptr -> i64
    llvm.br ^bb9(%69 : i64)
  ^bb9(%74: i64):  // 2 preds: ^bb8, ^bb13
    %75 = llvm.icmp "slt" %74, %73 : i64
    llvm.cond_br %75, ^bb10, ^bb14
  ^bb10:  // pred: ^bb9
    %76 = llvm.extractvalue %64[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %77 = llvm.getelementptr inbounds|nuw %76[%74] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    %78 = llvm.load %77 : !llvm.ptr -> i64
    %79 = llvm.extractvalue %62[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %80 = llvm.getelementptr inbounds|nuw %79[%74] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %81 = llvm.load %80 : !llvm.ptr -> f32
    llvm.br ^bb11(%21 : i64)
  ^bb11(%82: i64):  // 2 preds: ^bb10, ^bb12
    %83 = llvm.icmp "slt" %82, %22 : i64
    llvm.cond_br %83, ^bb12, ^bb13
  ^bb12:  // pred: ^bb11
    %84 = llvm.extractvalue %50[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %85 = llvm.mlir.constant(32 : index) : i64
    %86 = llvm.mul %65, %85 overflow<nsw, nuw> : i64
    %87 = llvm.add %86, %82 overflow<nsw, nuw> : i64
    %88 = llvm.getelementptr inbounds|nuw %84[%87] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %89 = llvm.load %88 : !llvm.ptr -> f32
    %90 = llvm.extractvalue %19[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %91 = llvm.getelementptr inbounds|nuw %90[%65] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %92 = llvm.load %91 : !llvm.ptr -> f32
    %93 = llvm.extractvalue %13[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %94 = llvm.getelementptr inbounds|nuw %93[%65] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %95 = llvm.load %94 : !llvm.ptr -> f32
    %96 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %97 = llvm.mlir.constant(32 : index) : i64
    %98 = llvm.mul %78, %97 overflow<nsw, nuw> : i64
    %99 = llvm.add %98, %82 overflow<nsw, nuw> : i64
    %100 = llvm.getelementptr inbounds|nuw %96[%99] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %101 = llvm.load %100 : !llvm.ptr -> f32
    %102 = llvm.fsub %81, %92 : f32
    %103 = llvm.intr.exp(%102) : (f32) -> f32
    %104 = llvm.fdiv %103, %95 : f32
    %105 = llvm.fmul %104, %101 : f32
    %106 = llvm.fadd %89, %105 : f32
    %107 = llvm.extractvalue %50[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %108 = llvm.mlir.constant(32 : index) : i64
    %109 = llvm.mul %65, %108 overflow<nsw, nuw> : i64
    %110 = llvm.add %109, %82 overflow<nsw, nuw> : i64
    %111 = llvm.getelementptr inbounds|nuw %107[%110] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %106, %111 : f32, !llvm.ptr
    %112 = llvm.add %82, %20 : i64
    llvm.br ^bb11(%112 : i64)
  ^bb13:  // pred: ^bb11
    %113 = llvm.add %74, %20 : i64
    llvm.br ^bb9(%113 : i64)
  ^bb14:  // pred: ^bb9
    %114 = llvm.add %65, %20 : i64
    llvm.br ^bb7(%114 : i64)
  ^bb15:  // pred: ^bb7
    llvm.return %50 : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
  }
  llvm.func @main() {
    %0 = llvm.mlir.constant(32 : index) : i64
    %1 = llvm.mlir.zero : !llvm.ptr
    %2 = llvm.mlir.constant(0 : i32) : i32
    %3 = llvm.mlir.constant(2 : i32) : i32
    %4 = llvm.mlir.constant(1 : i32) : i32
    %5 = llvm.mlir.constant(262144 : i64) : i64
    %6 = llvm.mlir.constant(65536 : i64) : i64
    %7 = llvm.mlir.constant(1 : index) : i64
    %8 = llvm.mlir.constant(0 : index) : i64
    %9 = llvm.mlir.constant(64 : index) : i64
    %10 = llvm.mlir.constant(1.000000e-03 : f32) : f32
    %11 = llvm.mlir.constant(0.00999999977 : f32) : f32
    %12 = llvm.mlir.constant(3.000000e-01 : f32) : f32
    %13 = llvm.mlir.constant(6 : i64) : i64
    %14 = llvm.mlir.constant(13 : i64) : i64
    %15 = llvm.mlir.constant(2 : i64) : i64
    %16 = llvm.mlir.constant(0 : i64) : i64
    %17 = llvm.mlir.constant(11 : i64) : i64
    %18 = llvm.mlir.constant(0.000000e+00 : f32) : f32
    %19 = llvm.mlir.constant(64 : index) : i64
    %20 = llvm.mlir.constant(64 : index) : i64
    %21 = llvm.mlir.constant(1 : index) : i64
    %22 = llvm.mlir.constant(4096 : index) : i64
    %23 = llvm.mlir.zero : !llvm.ptr
    %24 = llvm.getelementptr %23[%22] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %25 = llvm.ptrtoint %24 : !llvm.ptr to i64
    %26 = llvm.mlir.constant(64 : index) : i64
    %27 = llvm.add %25, %26 : i64
    %28 = llvm.call @malloc(%27) : (i64) -> !llvm.ptr
    %29 = llvm.ptrtoint %28 : !llvm.ptr to i64
    %30 = llvm.mlir.constant(1 : index) : i64
    %31 = llvm.sub %26, %30 : i64
    %32 = llvm.add %29, %31 : i64
    %33 = llvm.urem %32, %26 : i64
    %34 = llvm.sub %32, %33 : i64
    %35 = llvm.inttoptr %34 : i64 to !llvm.ptr
    %36 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %37 = llvm.insertvalue %28, %36[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %38 = llvm.insertvalue %35, %37[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %39 = llvm.mlir.constant(0 : index) : i64
    %40 = llvm.insertvalue %39, %38[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %41 = llvm.insertvalue %19, %40[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %42 = llvm.insertvalue %20, %41[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %43 = llvm.insertvalue %20, %42[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %44 = llvm.insertvalue %21, %43[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    llvm.br ^bb1(%8 : i64)
  ^bb1(%45: i64):  // 2 preds: ^bb0, ^bb5
    %46 = llvm.icmp "slt" %45, %9 : i64
    llvm.cond_br %46, ^bb2, ^bb6
  ^bb2:  // pred: ^bb1
    llvm.br ^bb3(%8 : i64)
  ^bb3(%47: i64):  // 2 preds: ^bb2, ^bb4
    %48 = llvm.icmp "slt" %47, %9 : i64
    llvm.cond_br %48, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %49 = llvm.add %45, %47 : i64
    %50 = llvm.srem %49, %17 : i64
    %51 = llvm.icmp "eq" %50, %16 : i64
    %52 = llvm.mul %47, %15 : i64
    %53 = llvm.add %45, %52 : i64
    %54 = llvm.srem %53, %14 : i64
    %55 = llvm.sub %54, %13 : i64
    %56 = llvm.sitofp %55 : i64 to f32
    %57 = llvm.fmul %56, %12 : f32
    %58 = llvm.select %51, %57, %18 : i1, f32
    %59 = llvm.extractvalue %44[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %60 = llvm.mlir.constant(64 : index) : i64
    %61 = llvm.mul %45, %60 overflow<nsw, nuw> : i64
    %62 = llvm.add %61, %47 overflow<nsw, nuw> : i64
    %63 = llvm.getelementptr inbounds|nuw %59[%62] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %58, %63 : f32, !llvm.ptr
    %64 = llvm.add %47, %7 : i64
    llvm.br ^bb3(%64 : i64)
  ^bb5:  // pred: ^bb3
    %65 = llvm.add %45, %7 : i64
    llvm.br ^bb1(%65 : i64)
  ^bb6:  // pred: ^bb1
    %66 = llvm.mlir.constant(2 : index) : i64
    %67 = llvm.mlir.constant(1 : index) : i64
    %68 = llvm.alloca %66 x i64 : (i64) -> !llvm.ptr
    %69 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %70 = llvm.insertvalue %68, %69[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %71 = llvm.insertvalue %68, %70[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %72 = llvm.mlir.constant(0 : index) : i64
    %73 = llvm.insertvalue %72, %71[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %74 = llvm.insertvalue %66, %73[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %75 = llvm.insertvalue %67, %74[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %76 = llvm.extractvalue %75[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %77 = llvm.getelementptr inbounds|nuw %76[%8] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %6, %77 : i64, !llvm.ptr
    %78 = llvm.extractvalue %75[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %79 = llvm.getelementptr inbounds|nuw %78[%7] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %5, %79 : i64, !llvm.ptr
    %80 = llvm.mlir.constant(2 : index) : i64
    %81 = llvm.mlir.constant(1 : index) : i64
    %82 = llvm.alloca %80 x i64 : (i64) -> !llvm.ptr
    %83 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %84 = llvm.insertvalue %82, %83[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %85 = llvm.insertvalue %82, %84[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %86 = llvm.mlir.constant(0 : index) : i64
    %87 = llvm.insertvalue %86, %85[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %88 = llvm.insertvalue %80, %87[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %89 = llvm.insertvalue %81, %88[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %90 = llvm.extractvalue %89[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %91 = llvm.getelementptr inbounds|nuw %90[%8] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %9, %91 : i64, !llvm.ptr
    %92 = llvm.extractvalue %89[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %93 = llvm.getelementptr inbounds|nuw %92[%7] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %9, %93 : i64, !llvm.ptr
    %94 = llvm.mlir.constant(2 : index) : i64
    %95 = llvm.mlir.constant(1 : index) : i64
    %96 = llvm.alloca %94 x i64 : (i64) -> !llvm.ptr
    %97 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %98 = llvm.insertvalue %96, %97[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %99 = llvm.insertvalue %96, %98[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %100 = llvm.mlir.constant(0 : index) : i64
    %101 = llvm.insertvalue %100, %99[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %102 = llvm.insertvalue %94, %101[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %103 = llvm.insertvalue %95, %102[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %104 = llvm.extractvalue %103[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %105 = llvm.getelementptr inbounds|nuw %104[%8] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %8, %105 : i64, !llvm.ptr
    %106 = llvm.extractvalue %103[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %107 = llvm.getelementptr inbounds|nuw %106[%7] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %7, %107 : i64, !llvm.ptr
    %108 = llvm.extractvalue %89[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %109 = llvm.extractvalue %89[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %110 = llvm.extractvalue %89[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %111 = llvm.extractvalue %89[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %112 = llvm.extractvalue %89[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %113 = llvm.extractvalue %89[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %114 = llvm.extractvalue %89[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %115 = llvm.extractvalue %89[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %116 = llvm.extractvalue %89[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %117 = llvm.extractvalue %89[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %118 = llvm.extractvalue %75[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %119 = llvm.extractvalue %75[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %120 = llvm.extractvalue %75[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %121 = llvm.extractvalue %75[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %122 = llvm.extractvalue %75[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %123 = llvm.extractvalue %103[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %124 = llvm.extractvalue %103[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %125 = llvm.extractvalue %103[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %126 = llvm.extractvalue %103[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %127 = llvm.extractvalue %103[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %128 = llvm.extractvalue %103[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %129 = llvm.extractvalue %103[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %130 = llvm.extractvalue %103[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %131 = llvm.extractvalue %103[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %132 = llvm.extractvalue %103[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %133 = llvm.call @newSparseTensor(%108, %109, %110, %111, %112, %113, %114, %115, %116, %117, %118, %119, %120, %121, %122, %123, %124, %125, %126, %127, %128, %129, %130, %131, %132, %4, %4, %3, %2, %1) : (!llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, i32, i32, i32, i32, !llvm.ptr) -> !llvm.ptr
    %134 = llvm.mlir.constant(2 : index) : i64
    %135 = llvm.mlir.constant(1 : index) : i64
    %136 = llvm.alloca %134 x i64 : (i64) -> !llvm.ptr
    %137 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %138 = llvm.insertvalue %136, %137[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %139 = llvm.insertvalue %136, %138[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %140 = llvm.mlir.constant(0 : index) : i64
    %141 = llvm.insertvalue %140, %139[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %142 = llvm.insertvalue %134, %141[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %143 = llvm.insertvalue %135, %142[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %144 = llvm.mlir.constant(1 : index) : i64
    %145 = llvm.alloca %144 x f32 : (i64) -> !llvm.ptr
    %146 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64)>
    %147 = llvm.insertvalue %145, %146[0] : !llvm.struct<(ptr, ptr, i64)> 
    %148 = llvm.insertvalue %145, %147[1] : !llvm.struct<(ptr, ptr, i64)> 
    %149 = llvm.mlir.constant(0 : index) : i64
    %150 = llvm.insertvalue %149, %148[2] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.br ^bb7(%8 : i64)
  ^bb7(%151: i64):  // 2 preds: ^bb6, ^bb13
    %152 = llvm.icmp "slt" %151, %9 : i64
    llvm.cond_br %152, ^bb8, ^bb14
  ^bb8:  // pred: ^bb7
    llvm.br ^bb9(%8 : i64)
  ^bb9(%153: i64):  // 2 preds: ^bb8, ^bb12
    %154 = llvm.icmp "slt" %153, %9 : i64
    llvm.cond_br %154, ^bb10, ^bb13
  ^bb10:  // pred: ^bb9
    %155 = llvm.extractvalue %44[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %156 = llvm.mlir.constant(64 : index) : i64
    %157 = llvm.mul %151, %156 overflow<nsw, nuw> : i64
    %158 = llvm.add %157, %153 overflow<nsw, nuw> : i64
    %159 = llvm.getelementptr inbounds|nuw %155[%158] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %160 = llvm.load %159 : !llvm.ptr -> f32
    %161 = llvm.fcmp "une" %160, %18 : f32
    llvm.cond_br %161, ^bb11, ^bb12
  ^bb11:  // pred: ^bb10
    %162 = llvm.extractvalue %143[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %163 = llvm.getelementptr inbounds|nuw %162[%8] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %151, %163 : i64, !llvm.ptr
    %164 = llvm.extractvalue %143[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %165 = llvm.getelementptr inbounds|nuw %164[%7] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %153, %165 : i64, !llvm.ptr
    %166 = llvm.extractvalue %150[1] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.store %160, %166 : f32, !llvm.ptr
    %167 = llvm.extractvalue %143[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %168 = llvm.extractvalue %143[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %169 = llvm.extractvalue %143[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %170 = llvm.extractvalue %143[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %171 = llvm.extractvalue %143[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %172 = llvm.extractvalue %150[0] : !llvm.struct<(ptr, ptr, i64)> 
    %173 = llvm.extractvalue %150[1] : !llvm.struct<(ptr, ptr, i64)> 
    %174 = llvm.extractvalue %150[2] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.call @lexInsertF32(%133, %167, %168, %169, %170, %171, %172, %173, %174) : (!llvm.ptr, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64) -> ()
    llvm.br ^bb12
  ^bb12:  // 2 preds: ^bb10, ^bb11
    %175 = llvm.add %153, %7 : i64
    llvm.br ^bb9(%175 : i64)
  ^bb13:  // pred: ^bb9
    %176 = llvm.add %151, %7 : i64
    llvm.br ^bb7(%176 : i64)
  ^bb14:  // pred: ^bb7
    llvm.call @endLexInsert(%133) : (!llvm.ptr) -> ()
    %177 = llvm.mlir.constant(64 : index) : i64
    %178 = llvm.mlir.constant(32 : index) : i64
    %179 = llvm.mlir.constant(1 : index) : i64
    %180 = llvm.mlir.constant(2048 : index) : i64
    %181 = llvm.mlir.zero : !llvm.ptr
    %182 = llvm.getelementptr %181[%180] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %183 = llvm.ptrtoint %182 : !llvm.ptr to i64
    %184 = llvm.mlir.constant(64 : index) : i64
    %185 = llvm.add %183, %184 : i64
    %186 = llvm.call @malloc(%185) : (i64) -> !llvm.ptr
    %187 = llvm.ptrtoint %186 : !llvm.ptr to i64
    %188 = llvm.mlir.constant(1 : index) : i64
    %189 = llvm.sub %184, %188 : i64
    %190 = llvm.add %187, %189 : i64
    %191 = llvm.urem %190, %184 : i64
    %192 = llvm.sub %190, %191 : i64
    %193 = llvm.inttoptr %192 : i64 to !llvm.ptr
    %194 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %195 = llvm.insertvalue %186, %194[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %196 = llvm.insertvalue %193, %195[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %197 = llvm.mlir.constant(0 : index) : i64
    %198 = llvm.insertvalue %197, %196[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %199 = llvm.insertvalue %177, %198[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %200 = llvm.insertvalue %178, %199[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %201 = llvm.insertvalue %178, %200[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %202 = llvm.insertvalue %179, %201[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    llvm.br ^bb15(%8 : i64)
  ^bb15(%203: i64):  // 2 preds: ^bb14, ^bb19
    %204 = llvm.icmp "slt" %203, %9 : i64
    llvm.cond_br %204, ^bb16, ^bb20
  ^bb16:  // pred: ^bb15
    llvm.br ^bb17(%8 : i64)
  ^bb17(%205: i64):  // 2 preds: ^bb16, ^bb18
    %206 = llvm.icmp "slt" %205, %0 : i64
    llvm.cond_br %206, ^bb18, ^bb19
  ^bb18:  // pred: ^bb17
    %207 = llvm.sitofp %203 : i64 to f32
    %208 = llvm.sitofp %205 : i64 to f32
    %209 = llvm.fmul %207, %11 : f32
    %210 = llvm.fmul %208, %10 : f32
    %211 = llvm.fadd %209, %210 : f32
    %212 = llvm.extractvalue %202[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %213 = llvm.mlir.constant(32 : index) : i64
    %214 = llvm.mul %203, %213 overflow<nsw, nuw> : i64
    %215 = llvm.add %214, %205 overflow<nsw, nuw> : i64
    %216 = llvm.getelementptr inbounds|nuw %212[%215] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %211, %216 : f32, !llvm.ptr
    %217 = llvm.add %205, %7 : i64
    llvm.br ^bb17(%217 : i64)
  ^bb19:  // pred: ^bb17
    %218 = llvm.add %203, %7 : i64
    llvm.br ^bb15(%218 : i64)
  ^bb20:  // pred: ^bb15
    %219 = llvm.call @row_max(%133) : (!llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %220 = llvm.extractvalue %219[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %221 = llvm.extractvalue %219[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %222 = llvm.extractvalue %219[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %223 = llvm.extractvalue %219[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %224 = llvm.extractvalue %219[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %225 = llvm.call @row_expsum(%133, %220, %221, %222, %223, %224) : (!llvm.ptr, !llvm.ptr, !llvm.ptr, i64, i64, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %226 = llvm.extractvalue %219[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %227 = llvm.extractvalue %219[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %228 = llvm.extractvalue %219[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %229 = llvm.extractvalue %219[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %230 = llvm.extractvalue %219[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %231 = llvm.extractvalue %225[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %232 = llvm.extractvalue %225[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %233 = llvm.extractvalue %225[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %234 = llvm.extractvalue %225[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %235 = llvm.extractvalue %225[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %236 = llvm.extractvalue %202[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %237 = llvm.extractvalue %202[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %238 = llvm.extractvalue %202[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %239 = llvm.extractvalue %202[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %240 = llvm.extractvalue %202[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %241 = llvm.extractvalue %202[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %242 = llvm.extractvalue %202[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %243 = llvm.call @weighted_aggregate(%133, %226, %227, %228, %229, %230, %231, %232, %233, %234, %235, %236, %237, %238, %239, %240, %241, %242) : (!llvm.ptr, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, i64, i64) -> !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %244 = llvm.mlir.constant(1 : index) : i64
    %245 = llvm.alloca %244 x !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> : (i64) -> !llvm.ptr
    llvm.store %243, %245 : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>, !llvm.ptr
    %246 = llvm.mlir.constant(2 : index) : i64
    %247 = llvm.mlir.poison : !llvm.struct<(i64, ptr)>
    %248 = llvm.insertvalue %246, %247[0] : !llvm.struct<(i64, ptr)> 
    %249 = llvm.insertvalue %245, %248[1] : !llvm.struct<(i64, ptr)> 
    %250 = llvm.extractvalue %249[0] : !llvm.struct<(i64, ptr)> 
    %251 = llvm.extractvalue %249[1] : !llvm.struct<(i64, ptr)> 
    llvm.call @printMemrefF32(%250, %251) : (i64, !llvm.ptr) -> ()
    llvm.call @delSparseTensor(%133) : (!llvm.ptr) -> ()
    llvm.return
  }
}

