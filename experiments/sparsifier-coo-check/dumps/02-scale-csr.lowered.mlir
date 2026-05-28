module {
  llvm.func @malloc(i64) -> !llvm.ptr
  llvm.mlir.global private constant @vector_print_str_7(dense<[45, 45, 45, 45, 10, 0]> : tensor<6xi8>) {addr_space = 0 : i32} : !llvm.array<6 x i8>
  llvm.func @printF32(f32)
  llvm.mlir.global private constant @vector_print_str_6(dense<[118, 97, 108, 117, 101, 115, 32, 58, 32, 0]> : tensor<10xi8>) {addr_space = 0 : i32} : !llvm.array<10 x i8>
  llvm.mlir.global private constant @vector_print_str_5(dense<[93, 32, 58, 32, 0]> : tensor<5xi8>) {addr_space = 0 : i32} : !llvm.array<5 x i8>
  llvm.mlir.global private constant @vector_print_str_4(dense<[99, 114, 100, 91, 0]> : tensor<5xi8>) {addr_space = 0 : i32} : !llvm.array<5 x i8>
  llvm.func @printI64(i64)
  llvm.mlir.global private constant @vector_print_str_3(dense<[93, 32, 58, 32, 0]> : tensor<5xi8>) {addr_space = 0 : i32} : !llvm.array<5 x i8>
  llvm.mlir.global private constant @vector_print_str_2(dense<[112, 111, 115, 91, 0]> : tensor<5xi8>) {addr_space = 0 : i32} : !llvm.array<5 x i8>
  llvm.mlir.global private constant @vector_print_str_1(dense<[108, 118, 108, 32, 61, 32, 0]> : tensor<7xi8>) {addr_space = 0 : i32} : !llvm.array<7 x i8>
  llvm.func @printClose()
  llvm.func @printComma()
  llvm.func @printOpen()
  llvm.mlir.global private constant @vector_print_str_0(dense<[100, 105, 109, 32, 61, 32, 0]> : tensor<7xi8>) {addr_space = 0 : i32} : !llvm.array<7 x i8>
  llvm.func @printNewline()
  llvm.func @printU64(i64)
  llvm.func @printString(!llvm.ptr)
  llvm.mlir.global private constant @vector_print_str(dense<[45, 45, 45, 45, 32, 83, 112, 97, 114, 115, 101, 32, 84, 101, 110, 115, 111, 114, 32, 45, 45, 45, 45, 10, 110, 115, 101, 32, 61, 32, 0]> : tensor<31xi8>) {addr_space = 0 : i32} : !llvm.array<31 x i8>
  llvm.func @delSparseTensor(!llvm.ptr) attributes {sym_visibility = "private"}
  llvm.func private @sparseCoordinates32(%arg0: !llvm.ptr, %arg1: i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> attributes {llvm.emit_c_interface, sym_visibility = "private"} {
    %0 = llvm.mlir.constant(1 : index) : i64
    %1 = llvm.alloca %0 x !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> : (i64) -> !llvm.ptr
    llvm.call @_mlir_ciface_sparseCoordinates32(%1, %arg0, %arg1) : (!llvm.ptr, !llvm.ptr, i64) -> ()
    %2 = llvm.load %1 : !llvm.ptr -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.return %2 : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  }
  llvm.func @_mlir_ciface_sparseCoordinates32(!llvm.ptr, !llvm.ptr, i64) attributes {llvm.emit_c_interface, sym_visibility = "private"}
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
  llvm.func @sparse_scale(%arg0: !llvm.ptr) -> !llvm.ptr {
    %0 = llvm.mlir.constant(1 : index) : i64
    %1 = llvm.mlir.constant(0 : index) : i64
    %2 = llvm.mlir.constant(8 : index) : i64
    %3 = llvm.mlir.constant(2.000000e+00 : f32) : f32
    %4 = llvm.call @sparseValuesF32(%arg0) : (!llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %5 = llvm.call @sparsePositions32(%arg0, %0) : (!llvm.ptr, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.br ^bb1(%1 : i64)
  ^bb1(%6: i64):  // 2 preds: ^bb0, ^bb5
    %7 = llvm.icmp "slt" %6, %2 : i64
    llvm.cond_br %7, ^bb2, ^bb6
  ^bb2:  // pred: ^bb1
    %8 = llvm.extractvalue %5[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %9 = llvm.getelementptr inbounds|nuw %8[%6] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %10 = llvm.load %9 : !llvm.ptr -> i32
    %11 = llvm.zext %10 : i32 to i64
    %12 = llvm.add %6, %0 : i64
    %13 = llvm.extractvalue %5[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %14 = llvm.getelementptr inbounds|nuw %13[%12] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %15 = llvm.load %14 : !llvm.ptr -> i32
    %16 = llvm.zext %15 : i32 to i64
    llvm.br ^bb3(%11 : i64)
  ^bb3(%17: i64):  // 2 preds: ^bb2, ^bb4
    %18 = llvm.icmp "slt" %17, %16 : i64
    llvm.cond_br %18, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %19 = llvm.extractvalue %4[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %20 = llvm.getelementptr inbounds|nuw %19[%17] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %21 = llvm.load %20 : !llvm.ptr -> f32
    %22 = llvm.fmul %21, %3 : f32
    %23 = llvm.extractvalue %4[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %24 = llvm.getelementptr inbounds|nuw %23[%17] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %22, %24 : f32, !llvm.ptr
    %25 = llvm.add %17, %0 : i64
    llvm.br ^bb3(%25 : i64)
  ^bb5:  // pred: ^bb3
    %26 = llvm.add %6, %0 : i64
    llvm.br ^bb1(%26 : i64)
  ^bb6:  // pred: ^bb1
    llvm.return %arg0 : !llvm.ptr
  }
  llvm.func @main() {
    %0 = llvm.mlir.addressof @vector_print_str_7 : !llvm.ptr
    %1 = llvm.mlir.addressof @vector_print_str_6 : !llvm.ptr
    %2 = llvm.mlir.addressof @vector_print_str_5 : !llvm.ptr
    %3 = llvm.mlir.addressof @vector_print_str_4 : !llvm.ptr
    %4 = llvm.mlir.addressof @vector_print_str_3 : !llvm.ptr
    %5 = llvm.mlir.addressof @vector_print_str_2 : !llvm.ptr
    %6 = llvm.mlir.addressof @vector_print_str_1 : !llvm.ptr
    %7 = llvm.mlir.addressof @vector_print_str_0 : !llvm.ptr
    %8 = llvm.mlir.addressof @vector_print_str : !llvm.ptr
    %9 = llvm.mlir.constant(0.000000e+00 : f32) : f32
    %10 = llvm.mlir.constant(3 : index) : i64
    %11 = llvm.mlir.constant(0 : index) : i64
    %12 = llvm.mlir.constant(8 : index) : i64
    %13 = llvm.mlir.zero : !llvm.ptr
    %14 = llvm.mlir.constant(0 : i32) : i32
    %15 = llvm.mlir.constant(2 : i32) : i32
    %16 = llvm.mlir.constant(262144 : i64) : i64
    %17 = llvm.mlir.constant(65536 : i64) : i64
    %18 = llvm.mlir.constant(1 : index) : i64
    %19 = llvm.mlir.constant(8 : index) : i64
    %20 = llvm.mlir.constant(8 : index) : i64
    %21 = llvm.mlir.constant(1 : index) : i64
    %22 = llvm.mlir.constant(64 : index) : i64
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
    llvm.br ^bb1(%11 : i64)
  ^bb1(%45: i64):  // 2 preds: ^bb0, ^bb5
    %46 = llvm.icmp "slt" %45, %12 : i64
    llvm.cond_br %46, ^bb2, ^bb6
  ^bb2:  // pred: ^bb1
    llvm.br ^bb3(%11 : i64)
  ^bb3(%47: i64):  // 2 preds: ^bb2, ^bb4
    %48 = llvm.icmp "slt" %47, %12 : i64
    llvm.cond_br %48, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %49 = llvm.add %45, %47 : i64
    %50 = llvm.uitofp %49 : i64 to f32
    %51 = llvm.urem %49, %10 : i64
    %52 = llvm.icmp "eq" %51, %11 : i64
    %53 = llvm.select %52, %50, %9 : i1, f32
    %54 = llvm.extractvalue %44[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %55 = llvm.mlir.constant(8 : index) : i64
    %56 = llvm.mul %45, %55 overflow<nsw, nuw> : i64
    %57 = llvm.add %56, %47 overflow<nsw, nuw> : i64
    %58 = llvm.getelementptr inbounds|nuw %54[%57] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %53, %58 : f32, !llvm.ptr
    %59 = llvm.add %47, %18 : i64
    llvm.br ^bb3(%59 : i64)
  ^bb5:  // pred: ^bb3
    %60 = llvm.add %45, %18 : i64
    llvm.br ^bb1(%60 : i64)
  ^bb6:  // pred: ^bb1
    %61 = llvm.mlir.constant(2 : index) : i64
    %62 = llvm.mlir.constant(1 : index) : i64
    %63 = llvm.alloca %61 x i64 : (i64) -> !llvm.ptr
    %64 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %65 = llvm.insertvalue %63, %64[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %66 = llvm.insertvalue %63, %65[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %67 = llvm.mlir.constant(0 : index) : i64
    %68 = llvm.insertvalue %67, %66[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %69 = llvm.insertvalue %61, %68[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %70 = llvm.insertvalue %62, %69[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %71 = llvm.extractvalue %70[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %72 = llvm.getelementptr inbounds|nuw %71[%11] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %17, %72 : i64, !llvm.ptr
    %73 = llvm.extractvalue %70[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %74 = llvm.getelementptr inbounds|nuw %73[%18] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %16, %74 : i64, !llvm.ptr
    %75 = llvm.mlir.constant(2 : index) : i64
    %76 = llvm.mlir.constant(1 : index) : i64
    %77 = llvm.alloca %75 x i64 : (i64) -> !llvm.ptr
    %78 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %79 = llvm.insertvalue %77, %78[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %80 = llvm.insertvalue %77, %79[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %81 = llvm.mlir.constant(0 : index) : i64
    %82 = llvm.insertvalue %81, %80[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %83 = llvm.insertvalue %75, %82[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %84 = llvm.insertvalue %76, %83[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %85 = llvm.extractvalue %84[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %86 = llvm.getelementptr inbounds|nuw %85[%11] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %12, %86 : i64, !llvm.ptr
    %87 = llvm.extractvalue %84[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %88 = llvm.getelementptr inbounds|nuw %87[%18] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %12, %88 : i64, !llvm.ptr
    %89 = llvm.mlir.constant(2 : index) : i64
    %90 = llvm.mlir.constant(1 : index) : i64
    %91 = llvm.alloca %89 x i64 : (i64) -> !llvm.ptr
    %92 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %93 = llvm.insertvalue %91, %92[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %94 = llvm.insertvalue %91, %93[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %95 = llvm.mlir.constant(0 : index) : i64
    %96 = llvm.insertvalue %95, %94[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %97 = llvm.insertvalue %89, %96[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %98 = llvm.insertvalue %90, %97[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %99 = llvm.extractvalue %98[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %100 = llvm.getelementptr inbounds|nuw %99[%11] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %11, %100 : i64, !llvm.ptr
    %101 = llvm.extractvalue %98[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %102 = llvm.getelementptr inbounds|nuw %101[%18] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %18, %102 : i64, !llvm.ptr
    %103 = llvm.extractvalue %84[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %104 = llvm.extractvalue %84[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %105 = llvm.extractvalue %84[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %106 = llvm.extractvalue %84[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %107 = llvm.extractvalue %84[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %108 = llvm.extractvalue %84[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %109 = llvm.extractvalue %84[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %110 = llvm.extractvalue %84[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %111 = llvm.extractvalue %84[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %112 = llvm.extractvalue %84[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %113 = llvm.extractvalue %70[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %114 = llvm.extractvalue %70[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %115 = llvm.extractvalue %70[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %116 = llvm.extractvalue %70[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %117 = llvm.extractvalue %70[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %118 = llvm.extractvalue %98[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %119 = llvm.extractvalue %98[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %120 = llvm.extractvalue %98[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %121 = llvm.extractvalue %98[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %122 = llvm.extractvalue %98[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %123 = llvm.extractvalue %98[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %124 = llvm.extractvalue %98[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %125 = llvm.extractvalue %98[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %126 = llvm.extractvalue %98[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %127 = llvm.extractvalue %98[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %128 = llvm.call @newSparseTensor(%103, %104, %105, %106, %107, %108, %109, %110, %111, %112, %113, %114, %115, %116, %117, %118, %119, %120, %121, %122, %123, %124, %125, %126, %127, %15, %15, %15, %14, %13) : (!llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64, i64, i64, i32, i32, i32, i32, !llvm.ptr) -> !llvm.ptr
    %129 = llvm.mlir.constant(2 : index) : i64
    %130 = llvm.mlir.constant(1 : index) : i64
    %131 = llvm.alloca %129 x i64 : (i64) -> !llvm.ptr
    %132 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %133 = llvm.insertvalue %131, %132[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %134 = llvm.insertvalue %131, %133[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %135 = llvm.mlir.constant(0 : index) : i64
    %136 = llvm.insertvalue %135, %134[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %137 = llvm.insertvalue %129, %136[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %138 = llvm.insertvalue %130, %137[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %139 = llvm.mlir.constant(1 : index) : i64
    %140 = llvm.alloca %139 x f32 : (i64) -> !llvm.ptr
    %141 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64)>
    %142 = llvm.insertvalue %140, %141[0] : !llvm.struct<(ptr, ptr, i64)> 
    %143 = llvm.insertvalue %140, %142[1] : !llvm.struct<(ptr, ptr, i64)> 
    %144 = llvm.mlir.constant(0 : index) : i64
    %145 = llvm.insertvalue %144, %143[2] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.br ^bb7(%11 : i64)
  ^bb7(%146: i64):  // 2 preds: ^bb6, ^bb13
    %147 = llvm.icmp "slt" %146, %12 : i64
    llvm.cond_br %147, ^bb8, ^bb14
  ^bb8:  // pred: ^bb7
    llvm.br ^bb9(%11 : i64)
  ^bb9(%148: i64):  // 2 preds: ^bb8, ^bb12
    %149 = llvm.icmp "slt" %148, %12 : i64
    llvm.cond_br %149, ^bb10, ^bb13
  ^bb10:  // pred: ^bb9
    %150 = llvm.extractvalue %44[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %151 = llvm.mlir.constant(8 : index) : i64
    %152 = llvm.mul %146, %151 overflow<nsw, nuw> : i64
    %153 = llvm.add %152, %148 overflow<nsw, nuw> : i64
    %154 = llvm.getelementptr inbounds|nuw %150[%153] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %155 = llvm.load %154 : !llvm.ptr -> f32
    %156 = llvm.fcmp "une" %155, %9 : f32
    llvm.cond_br %156, ^bb11, ^bb12
  ^bb11:  // pred: ^bb10
    %157 = llvm.extractvalue %138[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %158 = llvm.getelementptr inbounds|nuw %157[%11] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %146, %158 : i64, !llvm.ptr
    %159 = llvm.extractvalue %138[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %160 = llvm.getelementptr inbounds|nuw %159[%18] : (!llvm.ptr, i64) -> !llvm.ptr, i64
    llvm.store %148, %160 : i64, !llvm.ptr
    %161 = llvm.extractvalue %145[1] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.store %155, %161 : f32, !llvm.ptr
    %162 = llvm.extractvalue %138[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %163 = llvm.extractvalue %138[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %164 = llvm.extractvalue %138[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %165 = llvm.extractvalue %138[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %166 = llvm.extractvalue %138[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %167 = llvm.extractvalue %145[0] : !llvm.struct<(ptr, ptr, i64)> 
    %168 = llvm.extractvalue %145[1] : !llvm.struct<(ptr, ptr, i64)> 
    %169 = llvm.extractvalue %145[2] : !llvm.struct<(ptr, ptr, i64)> 
    llvm.call @lexInsertF32(%128, %162, %163, %164, %165, %166, %167, %168, %169) : (!llvm.ptr, !llvm.ptr, !llvm.ptr, i64, i64, i64, !llvm.ptr, !llvm.ptr, i64) -> ()
    llvm.br ^bb12
  ^bb12:  // 2 preds: ^bb10, ^bb11
    %170 = llvm.add %148, %18 : i64
    llvm.br ^bb9(%170 : i64)
  ^bb13:  // pred: ^bb9
    %171 = llvm.add %146, %18 : i64
    llvm.br ^bb7(%171 : i64)
  ^bb14:  // pred: ^bb7
    llvm.call @endLexInsert(%128) : (!llvm.ptr) -> ()
    %172 = llvm.call @sparse_scale(%128) : (!llvm.ptr) -> !llvm.ptr
    %173 = llvm.call @sparseValuesF32(%172) : (!llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %174 = llvm.extractvalue %173[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    llvm.call @printString(%8) : (!llvm.ptr) -> ()
    llvm.call @printU64(%174) : (i64) -> ()
    llvm.call @printNewline() : () -> ()
    llvm.call @printString(%7) : (!llvm.ptr) -> ()
    llvm.call @printOpen() : () -> ()
    llvm.call @printU64(%12) : (i64) -> ()
    llvm.call @printComma() : () -> ()
    llvm.call @printU64(%12) : (i64) -> ()
    llvm.call @printClose() : () -> ()
    llvm.call @printNewline() : () -> ()
    llvm.call @printString(%6) : (!llvm.ptr) -> ()
    llvm.call @printOpen() : () -> ()
    llvm.call @printU64(%12) : (i64) -> ()
    llvm.call @printComma() : () -> ()
    llvm.call @printU64(%12) : (i64) -> ()
    llvm.call @printClose() : () -> ()
    llvm.call @printNewline() : () -> ()
    llvm.call @printString(%5) : (!llvm.ptr) -> ()
    llvm.call @printU64(%18) : (i64) -> ()
    llvm.call @printString(%4) : (!llvm.ptr) -> ()
    %175 = llvm.call @sparsePositions32(%172, %18) : (!llvm.ptr, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.call @printOpen() : () -> ()
    %176 = llvm.extractvalue %175[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    llvm.br ^bb15(%11 : i64)
  ^bb15(%177: i64):  // 2 preds: ^bb14, ^bb18
    %178 = llvm.icmp "slt" %177, %176 : i64
    llvm.cond_br %178, ^bb16, ^bb19
  ^bb16:  // pred: ^bb15
    %179 = llvm.extractvalue %175[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %180 = llvm.getelementptr inbounds|nuw %179[%177] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %181 = llvm.load %180 : !llvm.ptr -> i32
    %182 = llvm.sext %181 : i32 to i64
    llvm.call @printI64(%182) : (i64) -> ()
    %183 = llvm.add %177, %18 : i64
    %184 = llvm.icmp "ne" %183, %176 : i64
    llvm.cond_br %184, ^bb17, ^bb18
  ^bb17:  // pred: ^bb16
    llvm.call @printComma() : () -> ()
    llvm.br ^bb18
  ^bb18:  // 2 preds: ^bb16, ^bb17
    %185 = llvm.add %177, %18 : i64
    llvm.br ^bb15(%185 : i64)
  ^bb19:  // pred: ^bb15
    llvm.call @printClose() : () -> ()
    llvm.call @printNewline() : () -> ()
    llvm.call @printString(%3) : (!llvm.ptr) -> ()
    llvm.call @printU64(%18) : (i64) -> ()
    llvm.call @printString(%2) : (!llvm.ptr) -> ()
    %186 = llvm.call @sparseCoordinates32(%172, %18) : (!llvm.ptr, i64) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.call @printOpen() : () -> ()
    %187 = llvm.extractvalue %186[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    llvm.br ^bb20(%11 : i64)
  ^bb20(%188: i64):  // 2 preds: ^bb19, ^bb23
    %189 = llvm.icmp "slt" %188, %187 : i64
    llvm.cond_br %189, ^bb21, ^bb24
  ^bb21:  // pred: ^bb20
    %190 = llvm.extractvalue %186[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %191 = llvm.getelementptr inbounds|nuw %190[%188] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %192 = llvm.load %191 : !llvm.ptr -> i32
    %193 = llvm.sext %192 : i32 to i64
    llvm.call @printI64(%193) : (i64) -> ()
    %194 = llvm.add %188, %18 : i64
    %195 = llvm.icmp "ne" %194, %187 : i64
    llvm.cond_br %195, ^bb22, ^bb23
  ^bb22:  // pred: ^bb21
    llvm.call @printComma() : () -> ()
    llvm.br ^bb23
  ^bb23:  // 2 preds: ^bb21, ^bb22
    %196 = llvm.add %188, %18 : i64
    llvm.br ^bb20(%196 : i64)
  ^bb24:  // pred: ^bb20
    llvm.call @printClose() : () -> ()
    llvm.call @printNewline() : () -> ()
    llvm.call @printString(%1) : (!llvm.ptr) -> ()
    %197 = llvm.call @sparseValuesF32(%172) : (!llvm.ptr) -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.call @printOpen() : () -> ()
    %198 = llvm.extractvalue %197[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    llvm.br ^bb25(%11 : i64)
  ^bb25(%199: i64):  // 2 preds: ^bb24, ^bb28
    %200 = llvm.icmp "slt" %199, %198 : i64
    llvm.cond_br %200, ^bb26, ^bb29
  ^bb26:  // pred: ^bb25
    %201 = llvm.extractvalue %197[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)> 
    %202 = llvm.getelementptr inbounds|nuw %201[%199] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %203 = llvm.load %202 : !llvm.ptr -> f32
    llvm.call @printF32(%203) : (f32) -> ()
    %204 = llvm.add %199, %18 : i64
    %205 = llvm.icmp "ne" %204, %198 : i64
    llvm.cond_br %205, ^bb27, ^bb28
  ^bb27:  // pred: ^bb26
    llvm.call @printComma() : () -> ()
    llvm.br ^bb28
  ^bb28:  // 2 preds: ^bb26, ^bb27
    %206 = llvm.add %199, %18 : i64
    llvm.br ^bb25(%206 : i64)
  ^bb29:  // pred: ^bb25
    llvm.call @printClose() : () -> ()
    llvm.call @printNewline() : () -> ()
    llvm.call @printString(%0) : (!llvm.ptr) -> ()
    llvm.call @delSparseTensor(%172) : (!llvm.ptr) -> ()
    llvm.return
  }
}

