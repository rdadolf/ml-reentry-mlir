"""Golden-file comparison with configurable tolerances.

Goldens are numpy .npy files produced by harness/golden.py against the
PyG reference path. Compiled-output comparison uses np.testing.assert_allclose
with tolerances tuned per target (CPU tighter than GPU, since reduction order
varies on GPU).
"""

from __future__ import annotations

from pathlib import Path

import numpy as np


def compare(
    actual: np.ndarray,
    golden_path: Path,
    *,
    rtol: float = 1e-3,
    atol: float = 1e-4,
) -> None:
    """Raise AssertionError if `actual` does not match the saved golden within tolerance."""
    expected = np.load(golden_path)
    np.testing.assert_allclose(actual, expected, rtol=rtol, atol=atol)


def save_golden(array: np.ndarray, golden_path: Path) -> None:
    """Persist a golden output array."""
    golden_path.parent.mkdir(parents=True, exist_ok=True)
    np.save(golden_path, array)
