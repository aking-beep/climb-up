"""
Barranco Wall tileset: volcanic basalt, climbable faces with holds, loose
scree, ledge lips, and small props. 16 px tiles, 8 columns. The tile order is
read by src/features/climbing/render/tileset.ts; keep the two in step.

    python3 tools/art/tiles.py
"""

import numpy as np
from PIL import Image, ImageDraw

from pixel import OUT, fbm, hex_rgb, lit, quantize, ramp, rgba

T = 16
COLS = 8
ROWS = 3

ROCK = ramp("#1b1613", "#29221d", "#382f28", "#4a3f35", "#5e5144", "#766554", "#917d67")
FACE = ramp("#251f1a", "#342b24", "#463b31", "#5a4c40", "#705f50", "#8a7663", "#a48e77")
LOOSE = ramp("#2c241d", "#3f342a", "#55473a", "#6d5c4a", "#87735d", "#a38d72", "#c0a888")
LICHEN = [hex_rgb("#6f6c3e"), hex_rgb("#837d48"), hex_rgb("#958a52")]
LIP = [hex_rgb("#c6b497"), hex_rgb("#9c8a70"), hex_rgb("#6f604f")]
GRASS = [hex_rgb("#a99d5a"), hex_rgb("#867b44"), hex_rgb("#6a6236")]


def rock_tile(seed: int) -> Image.Image:
    rng = np.random.default_rng(1000 + seed)
    h = fbm(T, T, 2, 3, rng)
    v = 0.5 + (h - 0.5) * 0.5 + lit(h, 2.8)
    # Blocky fractures: thin darker seams.
    seams = fbm(T, T, 3, 2, rng)
    v[np.abs(seams - 0.5) < 0.035] -= 0.22
    rgb = quantize(np.clip(v, 0, 0.999), ROCK)
    # Lichen in a couple of small patches on lit rock, not scattered pixels.
    lich = fbm(T, T, 2, 2, rng)
    for y, x in zip(*np.where((lich > 0.68) & (v > 0.5))):
        rgb[y, x] = LICHEN[(x // 2 + y // 2 + seed) % len(LICHEN)]
    return rgba(rgb)


def face_tile(seed: int) -> Image.Image:
    rng = np.random.default_rng(2000 + seed)
    h = fbm(T, T, 2, 3, rng)
    v = 0.38 + (h - 0.5) * 0.45 + lit(h, 2.6)
    # A vertical crack that wanders, the line climbers follow.
    x = int(rng.integers(4, 12))
    for y in range(T):
        v[y, x % T] -= 0.32
        if rng.random() < 0.3:
            x += int(rng.integers(-1, 2))
    rgb = quantize(np.clip(v, 0, 0.999), FACE)
    img = rgba(rgb)
    d = ImageDraw.Draw(img)
    # Holds: a lit top edge over a dark pocket.
    for _ in range(2):
        hx, hy = int(rng.integers(2, 13)), int(rng.integers(2, 13))
        w = int(rng.integers(2, 4))
        d.line([(hx, hy), (hx + w, hy)], fill=tuple(FACE[6]) + (255,))
        d.line([(hx, hy + 1), (hx + w, hy + 1)], fill=tuple(FACE[0]) + (255,))
    return img


def loose_tile(seed: int) -> Image.Image:
    rng = np.random.default_rng(3000 + seed)
    h = fbm(T, T, 3, 2, rng)
    rgb = quantize(np.clip(0.25 + (h - 0.5) * 0.5, 0, 0.999), LOOSE)
    img = rgba(rgb)
    d = ImageDraw.Draw(img)
    for _ in range(7):
        cx, cy = int(rng.integers(0, T)), int(rng.integers(0, T))
        r = int(rng.integers(1, 3))
        tone = int(rng.integers(3, 6))
        d.ellipse([cx - r, cy - r + 1, cx + r, cy + r], fill=tuple(LOOSE[1]) + (255,))
        d.ellipse([cx - r, cy - r, cx + r, cy + r - 1], fill=tuple(LOOSE[tone]) + (255,))
        d.point((cx - r // 2, cy - r // 2), fill=tuple(LOOSE[6]) + (255,))
    return img


def lip_overlay(seed: int) -> Image.Image:
    """Lit top edge of a rock tile, with a few dry tussocks."""
    rng = np.random.default_rng(4000 + seed)
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    px = img.load()
    for x in range(T):
        px[x, 0] = LIP[0] + (255,)
        px[x, 1] = LIP[1] + (255,)
        if rng.random() < 0.6:
            px[x, 2] = LIP[2] + (255,)
    for _ in range(3):
        gx = int(rng.integers(0, T - 2))
        for i, height in enumerate((2, 3, 1)):
            for k in range(height):
                if 0 <= gx + i < T:
                    px[gx + i, max(0, 0 - k)] = GRASS[k % len(GRASS)] + (255,)
    return img


def shade_overlay() -> Image.Image:
    """Shadowed underside of a ledge."""
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    px = img.load()
    for y in range(T - 5, T):
        alpha = int(40 + (y - (T - 5)) * 34)
        for x in range(T):
            px[x, y] = (8, 6, 5, alpha)
    return img


def exposed_lip() -> Image.Image:
    """The narrow step: a pale worn edge and a hairline crack."""
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    px = img.load()
    for x in range(T):
        px[x, T - 2] = LIP[0] + (255,)
        px[x, T - 1] = LIP[1] + (255,)
    return img


def edge(side: str) -> Image.Image:
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    px = img.load()
    for y in range(T):
        if side == "left":
            px[0, y] = LIP[1] + (255,)
        else:
            px[T - 1, y] = (10, 8, 7, 255)
            px[T - 2, y] = (24, 19, 16, 200)
    return img


def under_ao() -> Image.Image:
    """Ambient occlusion on the air just beneath an overhang."""
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    px = img.load()
    for y in range(6):
        for x in range(T):
            px[x, y] = (10, 8, 6, int(120 - y * 20))
    return img


def cairn() -> Image.Image:
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stones = [(3, 12, 13, 15), (4, 9, 11, 12), (5, 6, 10, 9), (6, 3, 9, 6)]
    for i, (x0, y0, x1, y1) in enumerate(stones):
        d.ellipse([x0, y0, x1, y1], fill=tuple(ROCK[5 - i % 2]) + (255,), outline=tuple(ROCK[1]) + (255,))
        d.line([(x0 + 1, y0 + 1), (x1 - 2, y0 + 1)], fill=tuple(ROCK[6]) + (255,))
    return img


def rest_stone() -> Image.Image:
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 9, 14, 15], radius=3, fill=tuple(FACE[4]) + (255,), outline=tuple(FACE[1]) + (255,))
    d.line([(3, 10), (12, 10)], fill=tuple(FACE[6]) + (255,))
    # A folded mat on the stone.
    d.rectangle([4, 7, 11, 9], fill=(150, 52, 34, 255))
    d.line([(4, 7), (11, 7)], fill=(196, 96, 64, 255))
    return img


def signpost(part: str) -> Image.Image:
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wood, dark, light = (120, 82, 48, 255), (66, 42, 24, 255), (166, 122, 76, 255)
    if part == "top":
        d.rectangle([7, 6, 8, 15], fill=wood)
        d.polygon([(1, 3), (13, 3), (15, 6), (13, 9), (1, 9)], fill=wood, outline=dark)
        d.line([(2, 4), (12, 4)], fill=light)
        d.line([(3, 6), (10, 6)], fill=dark)
    else:
        d.rectangle([7, 0, 8, 13], fill=wood)
        d.line([(7, 0), (7, 13)], fill=light)
        d.ellipse([3, 12, 12, 15], fill=tuple(ROCK[3]) + (255,))
    return img


def main():
    sheet = Image.new("RGBA", (T * COLS, T * ROWS), (0, 0, 0, 0))
    tiles = (
        [rock_tile(i) for i in range(4)]
        + [face_tile(i) for i in range(4)]
        + [loose_tile(i) for i in range(4)]
        + [lip_overlay(0), lip_overlay(1), shade_overlay(), exposed_lip()]
        + [edge("left"), edge("right"), cairn(), rest_stone(), signpost("top"), signpost("bottom"), under_ao()]
    )
    for index, tile in enumerate(tiles):
        sheet.alpha_composite(tile, ((index % COLS) * T, (index // COLS) * T))
    path = OUT / "terrain" / "barranco-tiles.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    print(f"wrote {path} ({len(tiles)} tiles)")


if __name__ == "__main__":
    main()
