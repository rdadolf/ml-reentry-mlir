"""Phases group pipeline operations together to allow skipping/tagging/etc.

A `Phase` is either a `StagePhase` — an ordered list of passes/transforms/bundles
that is lazily materialized into a Lighthouse `PipelineDriver` when it runs — or a
`CallablePhase` wrapping a single callable (ingress steps and the context
handoff). The lazy part means a `StagePhase` doesn't need an MLIR context until
run time, which makes mucking with the phase structure (e.g. `--stop-after
import`) easier.

A `PhasePipeline` is an ordered list of phases plus the `run` that folds a module
through them.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import Callable
from typing import TYPE_CHECKING, Any, TypeVar

if TYPE_CHECKING:
    from mlir import ir

# Lighthouse imports are deferred into the methods that touch a context, so
# importing this module (e.g. just `import gnnc`) never pulls in the MLIR stack.


class PhaseNotReached(Exception):
    """A requested phase isn't in this pipeline, or the stop excluded it."""


class Phase(ABC):
    """A named pipeline phase.

    `passes` is the flattened, human-readable stage list `--trace` reports.
    `run` folds the module forward; `get_context` supplies the MLIR context
    lazily, so phases that don't need one never build it.
    """

    def __init__(self, name: str) -> None:
        self.name = name

    @property
    @abstractmethod
    def passes(self) -> list[str]: ...

    @abstractmethod
    def run(self, module: Any, get_context: Callable[[], ir.Context]) -> Any: ...


class CallablePhase(Phase):
    """A phase that is a single callable — ingress steps and the context handoff.

    `passes` (the labels `--trace` reports) is supplied at construction; the
    callable does the work and never touches an MLIR context here.
    """

    def __init__(self, name: str, fn: Callable[[Any], Any], passes: tuple[str, ...] = ()) -> None:
        super().__init__(name)
        self._fn = fn
        self._passes = list(passes)

    @property
    def passes(self) -> list[str]:
        return self._passes

    def run(self, module: Any, get_context: Callable[[], ir.Context]) -> Any:
        return self._fn(module)


class StagePhase(Phase):
    """A phase built from an ordered list of passes/transforms/bundles.

    Behaves like a `PipelineDriver` but defers the driver until the phase runs,
    so we don't need an MLIR context until run time. `passes` is filled in by
    `_materialize` and is unavailable (raises) before the phase has run.
    """

    def __init__(self, name: str) -> None:
        super().__init__(name)
        # (kind, spec) pairs replayed verbatim onto a driver in `_materialize`.
        self._items: list[tuple[str, str]] = []
        # Flattened stage list, filled by `_materialize` (None until then).
        self._passes: list[str] | None = None

    def __enter__(self) -> StagePhase:
        return self

    def __exit__(self, *exc) -> bool:
        if not self._items:
            # An empty phase is almost always a build bug (e.g. a conditional
            # that added nothing); surface it rather than silently no-op.
            raise ValueError(f"phase {self.name!r} registered no stages")
        return False

    @property
    def passes(self) -> list[str]:
        if self._passes is None:
            raise ValueError(
                f"phase {self.name!r} has not been materialized; its passes are unknown"
            )
        return self._passes

    def add_pass(self, spec: str) -> None:
        self._items.append(("pass", spec))

    def add_descriptor(self, spec: str) -> None:
        self._items.append(("descriptor", spec))

    def add_transform(self, spec: str) -> None:
        self._items.append(("transform", spec))

    def run(self, module: Any, get_context: Callable[[], ir.Context]) -> Any:
        return self._materialize(get_context()).apply(module)

    def _materialize(self, context: ir.Context):
        """Lazy construction of the lighthouse `PipelineDriver`. Also fills in
        `passes` — each item expanded the same way the driver runs it."""
        from lighthouse.pipeline.descriptor import Descriptor, PipelineDescriptor
        from lighthouse.pipeline.driver import PipelineDriver

        from gnnc.passes import registry
        from gnnc.pipeline.stage import PythonPassStage

        driver = PipelineDriver(context)
        passes: list[str] = []
        for kind, spec in self._items:
            if kind == "pass":
                # Python pass names are looked up here directly, since only we
                # know about that registry. Everything else is handed off to
                # lighthouse, which does its own lookups.
                name = Descriptor(spec).basename
                info = registry.find(name)
                if info is not None:
                    driver.add_stage(PythonPassStage(info.run, context, name=name))
                else:
                    driver.add_pass(Descriptor(spec))
                passes.append(spec)
            elif kind == "descriptor":
                driver.add_descriptor(Descriptor(spec))
                # Expand the bundle (including nested includes) for the listing,
                # the same flattening the driver does when it runs the descriptor.
                passes.extend(str(s) for s in PipelineDescriptor(Descriptor(spec)).get_stages())
            else:
                driver.add_transform(Descriptor(spec))
                passes.append(spec)
        self._passes = passes
        return driver


_P = TypeVar("_P", bound=Phase)


class PhasePipeline:
    """An ordered list of `Phase`s, representing an entire compilation pipeline.

    This effectively replaces lighthouse's top-level `PipelineDriver` in schedules.
    No passes or transforms are added directly to it. It just holds a list of
    phases, each of which holds the actual operations that eventually run.

    Use `add_phase` as a context manager to declare a stage phase and its
    contents, or `add_callable_phase` for a phase that is a single callable:

        pipeline = PhasePipeline()
        pipeline.add_callable_phase("import", do_import, passes=("fx-import",))
        with pipeline.add_phase("sparse-prep") as phase:
            phase.add_pass("valid-lighthouse-descriptor-or-python-pass-name")
    """

    def __init__(self) -> None:
        self._phases: list[Phase] = []

    def add_phase(self, name: str) -> StagePhase:
        """Declare a stage phase; use as a context manager and add its stages."""
        return self._append(StagePhase(name))

    def add_callable_phase(
        self, name: str, fn: Callable[[Any], Any], passes: tuple[str, ...] = ()
    ) -> CallablePhase:
        """Declare a phase that is a single callable (ingress, context handoff)."""
        return self._append(CallablePhase(name, fn, passes))

    def _append(self, phase: _P) -> _P:
        if self.find(phase.name) is not None:
            raise ValueError(f"duplicate phase name {phase.name!r}")
        self._phases.append(phase)
        return phase

    def extend(self, other: PhasePipeline) -> None:
        """Append another pipeline's phases (e.g. graft the schedule onto the frontend)."""
        for phase in other._phases:
            if self.find(phase.name) is not None:
                raise ValueError(f"duplicate phase name {phase.name!r}")
        self._phases.extend(other._phases)

    def names(self) -> list[str]:
        return [phase.name for phase in self._phases]

    def find(self, name: str) -> Phase | None:
        return next((phase for phase in self._phases if phase.name == name), None)

    def run(
        self,
        module: Any,
        get_context: Callable[[], ir.Context],
        *,
        stop_before: str | None = None,
        stop_after: str | None = None,
        print_ir_before: frozenset[str] = frozenset(),
        print_ir_after: frozenset[str] = frozenset(),
        emit: Callable[[str], None] = print,
    ) -> tuple[Any, list[tuple[str, tuple[str, ...]]]]:
        """Fold `module` through the phases, halting and tracing. Returns the
        resulting module and the in-order `(phase, passes)` that ran."""
        if stop_before and stop_after:
            raise ValueError("stop_before and stop_after are mutually exclusive")

        names = self.names()
        referenced = {n for n in (stop_before, stop_after) if n}
        referenced |= set(print_ir_before) | set(print_ir_after)
        unknown = referenced - set(names)
        if unknown:
            # Fail fast on a name this pipeline doesn't build — a typo, or a
            # conditional phase absent for this target.
            raise PhaseNotReached(f"unknown phase(s) {sorted(unknown)}; phases: {names}")

        end = len(self._phases)
        if stop_before:
            end = names.index(stop_before)
        elif stop_after:
            end = names.index(stop_after) + 1

        missed = (set(print_ir_before) | set(print_ir_after)) - set(names[:end])
        if missed:
            raise PhaseNotReached(
                f"can't print at phase(s) {sorted(missed)}; the stop excludes them"
            )

        trace: list[tuple[str, tuple[str, ...]]] = []
        for phase in self._phases[:end]:
            if phase.name in print_ir_before:
                emit(f"// -----// IR before {phase.name} //----- //\n{module}")
            module = phase.run(module, get_context)
            trace.append((phase.name, tuple(phase.passes)))
            if phase.name in print_ir_after:
                emit(f"// -----// IR after {phase.name} //----- //\n{module}")
        return module, trace
