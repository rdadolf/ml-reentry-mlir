add_mlir_library(GNNCTransforms
        SwitchBarFoo.cpp

        ADDITIONAL_HEADER_DIRS
        ${GNNC_SRC_DIR}/include/GNNC/Transforms

        DEPENDS
        GNNCTransformsPassesIncGen

        LINK_LIBS PUBLIC
        MLIRIR
        MLIRPass
        MLIRFuncDialect
        )
