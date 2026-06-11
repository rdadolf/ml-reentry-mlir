# Pass plugin loaded into upstream `mlir-opt` for lit testing.
#
# There's two ways to build a compiler downstream of MLIR:
#  - Build a loadable plugin .so for your passes
#  - Roll your own `<thing>-opt` program akin to `mlir-opt`
# We actually sort of do the latter already, but since we enable passes written
# in Python, it basically has to be written in Python (and `gnnc-opt` is). But
# we also enable the former to let `lit` run `mlir-opt` with our C++ passes,
# since it's lower overhead.
# TODO(RDA): This can technically be solved by carefully lazy-loading all the
#            various expensive imports when `gnnc-opt` is called only with C++
#            passes.
add_llvm_library(GNNCPlugin
        MODULE BUILDTREE_ONLY
        gnnc-plugin.cpp

        DEPENDS
        GNNCTransforms
        PLUGIN_TOOL
        mlir-opt

        LINK_LIBS
        GNNCTransforms
        )
