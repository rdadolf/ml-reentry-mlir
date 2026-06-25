"""Check that gnnc's C++ passes behave the way MLIR ones do."""

import pytest

# Skip cleanly if the C++ pass module hasn't been built and linked (mirrors the
# lit `REQUIRES: gnnc-cpp-passes` gate).
pytest.importorskip(
    "gnnc._gnncRegisterPasses",
    reason="gnnc C++ passes not built; run build-gnnc.sh + link-stack.sh",
)

GNNC_PASS = "func.func(gnnc-switch-bar-foo)"
UPSTREAM_PASS = "func.func(canonicalize)"
SRC = "func.func @bar() { return }\nfunc.func @baz() { return }"


@pytest.fixture(scope="module")
def ctx():
    """Avoid constructing multiple gnnc contexts for the module, since
    Lighthouse expects to load its dialects into a context only once per process."""
    from gnnc import get_context

    return get_context()


def test_cpp_pass_runs_inside_a_schedule(ctx):
    """Check gnnc passes work in a schedule the same as MLIR ones."""
    from mlir import ir

    from gnnc.pipeline.phase import PhasePipeline

    with ctx, ir.Location.unknown():
        module = ir.Module.parse(SRC)

        pipeline = PhasePipeline()
        with pipeline.add_phase("custom-cpp") as phase:
            phase.add_pass(GNNC_PASS)
            phase.add_pass(UPSTREAM_PASS)

        out, trace = pipeline.run(module, lambda: ctx)
        text = str(out)

    assert "@foo" in text and "func.func @bar" not in text
    # The schedule listing records the gnnc C++ pass like any other stage.
    assert trace == [("custom-cpp", (GNNC_PASS, UPSTREAM_PASS))]


def test_cpp_and_upstream_passes_resolve_identically(ctx):
    """Check pass name resolution is identical for gnnc and MLIR passes."""
    from mlir.passmanager import PassManager

    with ctx:
        # Neither raises: gnnc's pass sits in the registry beside upstream's.
        PassManager.parse(f"builtin.module({GNNC_PASS})")
        PassManager.parse(f"builtin.module({UPSTREAM_PASS})")
