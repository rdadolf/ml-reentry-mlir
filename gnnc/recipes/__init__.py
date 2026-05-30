"""recipes — named compiler pipelines, expressed as Lighthouse YAML.

A recipe is a YAML pipeline descriptor (Lighthouse's
`lighthouse.pipeline.descriptor` format): an ordered list of `pass:`,
`transform:` / `schedule:`, and `include:` stages. Recipes live in this
package as `<target>/<name>.yaml` and may `include:` Lighthouse's
bundled descriptors (`bufferization.yaml`, `llvm_lowering.yaml`,
`cleanup.yaml`) — Lighthouse's include resolver searches the including
file's directory first, then its own `pipeline/descriptors/` dir, so a
bare `include: bufferization.yaml` resolves to the upstream bundle.

This replaces the earlier Python-callable registry: the registry couldn't
`include:` upstream bundles or be driven by Lighthouse's
`CompilerDriver`. GNN-/sparsity-specific schedules (the `transform:`
stages our recipes will reference) land in a later phase under
`gnnc.schedule`; for now only the generic CPU lowering recipe exists.

Lighthouse imports are lazy so `import gnnc` works without the
source-built MLIR stack present.
"""

from __future__ import annotations

from pathlib import Path

RECIPES_DIR = Path(__file__).parent

__all__ = ["RECIPES_DIR", "available", "resolve", "load", "build_driver"]


def available() -> list[str]:
    """Recipe names (`<target>/<stem>`) discoverable in this package."""
    return sorted(
        str(p.relative_to(RECIPES_DIR).with_suffix("")) for p in RECIPES_DIR.glob("*/*.yaml")
    )


def resolve(name: str) -> Path:
    """Map a recipe name (e.g. `cpu/passthrough`) to its YAML path.

    Raises ValueError listing the known recipes if the name is unknown.
    """
    path = RECIPES_DIR / f"{name}.yaml"
    if not path.is_file():
        raise ValueError(f"unknown recipe {name!r}; known recipes: {available()}")
    return path


def load(name: str):
    """Parse a recipe through Lighthouse, returning its flattened stage list.

    Validates the recipe (and any `include:`d bundles) without needing a
    payload module. Useful for `gnnc run`'s dry-run / validation path.
    """
    from lighthouse.pipeline.descriptor import Descriptor, PipelineDescriptor

    return PipelineDescriptor(Descriptor(str(resolve(name)))).get_stages()


def build_driver(name: str, payload_path: str):
    """Construct a Lighthouse `CompilerDriver` for `payload_path` with
    the recipe's stages applied. Caller invokes `.run()`.
    """
    from lighthouse.pipeline.driver import CompilerDriver

    driver = CompilerDriver(payload_path)
    driver.add_stages([str(resolve(name))])
    return driver
