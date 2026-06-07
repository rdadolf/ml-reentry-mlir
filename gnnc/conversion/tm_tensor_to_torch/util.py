"""Type introspection and construction for `!torch.vtensor` / `!torch.tensor`.

torch-mlir binds its dialect ops to Python but not its types — no
`VTensorType.get(...)` factory, no MLIR-style typed accessors. This module
emulates both.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from torch_mlir import ir

# Matches torch-mlir's convention (`?` is -1).
DYNAMIC_DIM = -1


_TORCH_TENSOR_HEAD = re.compile(r"^!torch\.(vtensor|tensor)(?:<(.+)>)?$")


def _split_top_level_commas(s: str) -> list[str]:
    """Split on commas not nested inside any of `<>`, `[]`, `{}`."""
    parts: list[str] = []
    depth = 0
    start = 0
    for i, c in enumerate(s):
        if c in "<[{":
            depth += 1
        elif c in ">]}":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append(s[start:i])
            start = i + 1
    parts.append(s[start:])
    return parts


@dataclass(frozen=True)
class TorchTensorTypeInfo:
    """Introspection for `!torch.vtensor` / `!torch.tensor`.

    Normal MLIR IRTypes have built-in properties, but torch-mlir doesn't. This
    is a facsimile of that interface to enable the same sort of introspection.
    """

    shape: tuple[int, ...] | None
    element_type: ir.Type | None
    encoding: str | None
    value_semantics: bool

    # --- ShapedType-style properties (match upstream MLIR Python)

    @property
    def rank(self) -> int:
        """Number of dimensions. Raises if unranked."""
        if self.shape is None:
            raise ValueError("unranked: no rank")
        return len(self.shape)

    @property
    def has_rank(self) -> bool:
        return self.shape is not None

    @property
    def has_dtype(self) -> bool:
        return self.element_type is not None

    @property
    def has_static_shape(self) -> bool:
        return self.has_rank and all(d != DYNAMIC_DIM for d in self.shape)

    def get_dim_size(self, i: int) -> int:
        if self.shape is None:
            raise ValueError("unranked: no dimensions to query")
        return self.shape[i]

    def is_dynamic_dim(self, i: int) -> bool:
        if self.shape is None:
            raise ValueError("unranked: no dimensions to query")
        return self.shape[i] == DYNAMIC_DIM

    @staticmethod
    def is_dynamic_size(d: int) -> bool:
        return d == DYNAMIC_DIM

    @staticmethod
    def get_dynamic_size() -> int:
        return DYNAMIC_DIM

    # --- alternate constructor

    @classmethod
    def from_type(cls, t: ir.Type) -> TorchTensorTypeInfo:
        """Build a `TorchTensorTypeInfo` which exposes type properties from a `!torch.*tensor`."""
        s = str(t)
        m = _TORCH_TENSOR_HEAD.match(s)
        if m is None:
            raise TypeError(f"not a torch tensor type: {s}")
        stem, body = m.group(1), m.group(2)
        value_semantics = stem == "vtensor"

        if body is None:
            # Bare form: no shape, no dtype, no encoding.
            return cls(None, None, None, value_semantics)

        parts = _split_top_level_commas(body)
        if not 2 <= len(parts) <= 3:
            raise TypeError(f"unexpected modifier structure in {s}")

        shape_str, dtype_str = parts[0], parts[1]
        encoding = parts[2] if len(parts) == 3 else None

        if shape_str == "*":
            shape: tuple[int, ...] | None = None
        elif shape_str.startswith("[") and shape_str.endswith("]"):
            inner = shape_str[1:-1]
            shape = tuple(DYNAMIC_DIM if d == "?" else int(d) for d in inner.split(",") if d)
        else:
            raise TypeError(f"unexpected shape form: {shape_str}")

        element_type = None if dtype_str == "unk" else ir.Type.parse(dtype_str, t.context)

        return cls(shape, element_type, encoding, value_semantics)


# --- Functions that mimic the missing *Tensor.get() bindings


def _torch_tensor_type(
    stem: str,
    shape: tuple[int, ...] | None,
    element_type: ir.Type | None,
    encoding: str | None,
    context: ir.Context,
) -> ir.Type:
    """Assemble torch tensor asm and parse to `ir.Type`. Shared by both factories."""
    if shape is None and element_type is None:
        asm = f"!torch.{stem}"
    else:
        shape_asm = (
            "*"
            if shape is None
            else "[" + ",".join("?" if d == DYNAMIC_DIM else str(d) for d in shape) + "]"
        )
        dtype_asm = "unk" if element_type is None else str(element_type)
        encoding_asm = f",{encoding}" if encoding else ""
        asm = f"!torch.{stem}<{shape_asm},{dtype_asm}{encoding_asm}>"
    return ir.Type.parse(asm, context)


def VTensor_get(
    shape: tuple[int, ...] | None,
    element_type: ir.Type | None,
    encoding: str | None = None,
    *,
    context: ir.Context,
) -> ir.Type:
    """Mirror of the missing `VTensorType.get(shape, element_type, encoding=None, *, context=None)`."""
    return _torch_tensor_type("vtensor", shape, element_type, encoding, context)


def Tensor_get(
    shape: tuple[int, ...] | None,
    element_type: ir.Type | None,
    encoding: str | None = None,
    *,
    context: ir.Context,
) -> ir.Type:
    """Mirror of the missing `NonValueTensorType.get(shape, element_type, encoding=None, *, context=None)`."""
    return _torch_tensor_type("tensor", shape, element_type, encoding, context)
