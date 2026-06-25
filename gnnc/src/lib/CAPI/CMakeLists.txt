# C interface to gnnc's pass registration. Exists so the Python extension can
# register gnnc's passes without compiling MLIR C++.
add_mlir_public_c_api_library(GNNCCAPI
        Registration.cpp

        LINK_LIBS PUBLIC
        GNNCTransforms
        )
