# Generates the lit.site.cfg.py that test/lit.cfg.py has always anticipated,
# injecting build-tree paths (the GNNCPlugin location). `ninja check-gnnc`
# runs the suite against the build tree. The same .mlir tests also run via
# `lit test/` / the VSCode runner directly — there the plugin path is derived
# from GNNC_CACHE_DIR instead (see lit.cfg.py).
set(GNNC_TEST_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(GNNC_PLUGIN_PATH ${CMAKE_BINARY_DIR}/lib/GNNCPlugin${CMAKE_SHARED_MODULE_SUFFIX})

configure_lit_site_cfg(
  ${CMAKE_CURRENT_SOURCE_DIR}/lit.site.cfg.py.in
  ${CMAKE_CURRENT_BINARY_DIR}/lit.site.cfg.py
  MAIN_CONFIG
  ${CMAKE_CURRENT_SOURCE_DIR}/lit.cfg.py
)

add_lit_testsuite(check-gnnc "Running the gnnc lit tests"
  ${CMAKE_CURRENT_BINARY_DIR}
  DEPENDS FileCheck mlir-opt GNNCPlugin
)
