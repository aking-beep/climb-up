"""
Shared helpers for the CLIMB UP art scripts: tileable noise, colour ramps,
ordered dithering, and a soft selective outline. Everything is seeded, so
the same script always writes the same pixels.
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "hd2d"

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=float) / 16.0 - 0.5


def hex_rgb(value: str) -> tuple:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def ramp(*colors: str) -> np.ndarray:
    return np.array([hex_rgb(c) for c in colors], dtype=np.uint8)


def value_noise(width: int, height: int, cells: int, rng: np.random.Generator, wrap: bool = True) -> np.ndarray:
    """Smooth value noise in 0..1. With wrap=True it tiles seamlessly."""
    cy = max(1, round(cells * height / width))
    grid = rng.random((cy + 1, cells + 1))
    if wrap:
        grid[-1, :] = grid[0, :]
        grid[:, -1] = grid[:, 0]
    ys = np.linspace(0, cy, height, endpoint=False)
    xs = np.linspace(0, cells, width, endpoint=False)
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = grid[y0][:, x0]
    b = grid[y0][:, x0 + 1]
    c = grid[y0 + 1][:, x0]
    d = grid[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bottom = c + (d - c) * fx[None, :]
    return top + (bottom - top) * fy[:, None]


def fbm(width: int, height: int, base: int, octaves: int, rng: np.random.Generator, wrap: bool = True) -> np.ndarray:
    total = np.zeros((height, width))
    amp = 1.0
    norm = 0.0
    cells = base
    for _ in range(octaves):
        total += value_noise(width, height, cells, rng, wrap) * amp
        norm += amp
        amp *= 0.5
        cells *= 2
    return total / norm


def lit(height: np.ndarray, strength: float = 4.0) -> np.ndarray:
    """Directional light from the upper left on a height field (wrapping)."""
    shifted = np.roll(np.roll(height, 1, axis=0), 1, axis=1)
    return (height - shifted) * strength


def quantize(values: np.ndarray, palette: np.ndarray, dither: float = 1.0) -> np.ndarray:
    """Map 0..1 values onto a palette with 4x4 ordered dithering."""
    h, w = values.shape
    threshold = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]
    steps = len(palette)
    index = np.clip(np.floor(values * steps + threshold * dither), 0, steps - 1).astype(int)
    return palette[index]


def rgba(rgb: np.ndarray, alpha: np.ndarray | None = None) -> Image.Image:
    h, w, _ = rgb.shape
    a = np.full((h, w), 255, dtype=np.uint8) if alpha is None else alpha.astype(np.uint8)
    return Image.fromarray(np.dstack([rgb.astype(np.uint8), a]), "RGBA")


def selective_outline(image: Image.Image, cell: tuple[int, int] | None = None, darken: float = 0.38) -> Image.Image:
    """
    Pixel-art "selout": every transparent pixel touching the sprite takes a
    darkened copy of its neighbour's colour instead of flat black. With
    `cell`, outlines never cross from one sheet frame into the next.
    """
    src = np.array(image.convert("RGBA"))
    out = src.copy()
    h, w, _ = src.shape
    opaque = src[:, :, 3] > 0
    for y in range(h):
        for x in range(w):
            if opaque[y, x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or not opaque[ny, nx]:
                    continue
                if cell and (nx // cell[0] != x // cell[0] or ny // cell[1] != y // cell[1]):
                    continue
                r, g, b, _ = src[ny, nx]
                out[y, x] = (int(r * darken), int(g * darken * 0.95), int(b * darken * 0.9), 255)
                break
    return Image.fromarray(out, "RGBA")
