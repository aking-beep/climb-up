"""
Terrain and props for the Godot Barranco Wall (godot/). 16 px tiles in one
atlas, 16 columns, read by godot/core/world/terrain_tiles.gd; keep the two
in step.

Atlas rows:
  0-1  basalt, autotiled: column = open-side mask (1 top, 2 right, 4 bottom,
       8 left), row = variant. Rounded corners, lit lip on top, shaded
       underside, darker sides.
  2    slope up-right (0-1), slope up-left (2-3), climbable face (4-7),
       loose scree face (8-11), scramble boulders (12-15)
  3    back wall, recessed rock behind ledges and faces (0-7);
       deep rock, the mountain's interior away from any edge (8-15)

Props are separate PNGs in godot/assets/terrain/props/.

    python3 tools/art/godot_barranco.py
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from pixel import fbm, hex_rgb, lit, quantize, ramp, selective_outline
from pixel import rgba as _rgba


def rgba(rgb):
    return _rgba(rgb).copy()  # writable

T = 16
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "assets" / "terrain"

ROCK = ramp("#1a1512", "#28211c", "#372e27", "#493e34", "#5d5043", "#746452", "#8f7c66")
BACK = ramp("#100d0c", "#17130f", "#1f1a16", "#28221d", "#322a24", "#3c332b")
FACE = ramp("#2a231d", "#3a3028", "#4d4136", "#625346", "#7a6857", "#94806b", "#ae9880")
LOOSE = ramp("#2c241d", "#3f342a", "#55473a", "#6d5c4a", "#87735d", "#a38d72", "#c0a888")
BOULDER = ramp("#2e2722", "#40362e", "#554839", "#6c5c4a", "#857260", "#9f8a74", "#b9a38a")
LIP = [hex_rgb("#cbb999"), hex_rgb("#a08e73"), hex_rgb("#716251")]
GRASS = [hex_rgb("#b0a45e"), hex_rgb("#8c8148"), hex_rgb("#6c6438")]
LICHEN = [hex_rgb("#6f6c3e"), hex_rgb("#837d48")]


def texture(ramp_, seed, base=0.5, strata=True):
    rng = np.random.default_rng(seed)
    h = fbm(T, T, 2, 3, rng)
    v = base + (h - 0.5) * 0.55 + lit(h, 2.6)
    if strata:  # lava-flow layering: faint horizontal bands
        band = fbm(T, T, 1, 2, rng)
        rows = np.arange(T)[:, None]
        v += 0.06 * np.sin((rows + band * 6) * 0.9)
    seams = fbm(T, T, 3, 2, rng)
    v[np.abs(seams - 0.5) < 0.03] -= 0.2
    return np.clip(v, 0, 0.999), rng


def rock(mask, variant):
    v, rng = texture(ROCK, 100 + variant * 17 + mask)
    top, right, bottom, left = mask & 1, mask & 2, mask & 4, mask & 8
    rows = np.arange(T)[:, None].repeat(T, 1).astype(float)
    cols = np.arange(T)[None, :].repeat(T, 0).astype(float)
    if bottom:  # underside in shadow
        v -= np.clip((rows - (T - 6)) / 6, 0, 1) * 0.35
    if left:
        v -= np.clip((2 - cols) / 2, 0, 1) * 0.12
    if right:
        v -= np.clip((cols - (T - 3)) / 3, 0, 1) * 0.22
    if top:
        v += np.clip((4 - rows) / 4, 0, 1) * 0.15
    rgb = quantize(np.clip(v, 0, 0.999), ROCK)
    img = rgba(rgb)
    px = img.load()
    lich = fbm(T, T, 2, 2, rng)
    for y, x in zip(*np.where((lich > 0.7) & (v > 0.55))):
        px[int(x), int(y)] = LICHEN[(x + y) % 2] + (255,)
    if top:
        for x in range(T):
            px[x, 0] = LIP[0] + (255,)
            px[x, 1] = LIP[1] + (255,)
            if rng.random() < 0.55:
                px[x, 2] = LIP[2] + (255,)
    # Round the corners where two open sides meet.
    corners = []
    if top and left:
        corners.append((0, 0, 1, 1))
    if top and right:
        corners.append((T - 1, 0, -1, 1))
    if bottom and left:
        corners.append((0, T - 1, 1, -1))
    if bottom and right:
        corners.append((T - 1, T - 1, -1, -1))
    for cx, cy, dx, dy in corners:
        for k, n in enumerate((3, 2, 1)):
            for i in range(n):
                px[cx + dx * i, cy + dy * k] = (0, 0, 0, 0)
        if top and cy == 0:
            px[cx + dx * 3, cy] = LIP[0] + (255,)
            px[cx + dx * 2, cy + 1] = LIP[1] + (255,)
            px[cx + dx * 1, cy + 2] = LIP[1] + (255,)
    return img


def slope(up_right, variant):
    v, rng = texture(ROCK, 300 + variant + (50 if up_right else 0))
    rgb = quantize(v, ROCK)
    img = rgba(rgb)
    px = img.load()
    for y in range(T):
        for x in range(T):
            surface = (T - 1 - x) if up_right else x  # floor height at column x
            if y < surface:
                px[x, y] = (0, 0, 0, 0)
            elif y == surface:
                px[x, y] = LIP[0] + (255,)
            elif y == surface + 1:
                px[x, y] = LIP[1] + (255,)
    return img


def face(ramp_, seed, holds=2, crack=True):
    v, rng = texture(ramp_, seed, base=0.42)
    if crack:
        x = int(rng.integers(4, 12))
        for y in range(T):
            v[y, x % T] -= 0.32
            if rng.random() < 0.3:
                x += int(rng.integers(-1, 2))
    img = rgba(quantize(np.clip(v, 0, 0.999), ramp_))
    d = ImageDraw.Draw(img)
    for _ in range(holds):
        hx, hy = int(rng.integers(2, 13)), int(rng.integers(2, 13))
        w = int(rng.integers(2, 4))
        d.line([(hx, hy), (hx + w, hy)], fill=tuple(ramp_[-1]) + (255,))
        d.line([(hx, hy + 1), (hx + w, hy + 1)], fill=tuple(ramp_[0]) + (255,))
    return img


def loose(seed):
    rng = np.random.default_rng(seed)
    h = fbm(T, T, 3, 2, rng)
    img = rgba(quantize(np.clip(0.28 + (h - 0.5) * 0.5, 0, 0.999), LOOSE))
    d = ImageDraw.Draw(img)
    for _ in range(8):
        cx, cy = int(rng.integers(0, T)), int(rng.integers(0, T))
        r = int(rng.integers(1, 3))
        tone = int(rng.integers(3, 6))
        d.ellipse([cx - r, cy - r + 1, cx + r, cy + r], fill=tuple(LOOSE[1]) + (255,))
        d.ellipse([cx - r, cy - r, cx + r, cy + r - 1], fill=tuple(LOOSE[tone]) + (255,))
        d.point((cx - r // 2, cy - r // 2), fill=tuple(LOOSE[6]) + (255,))
    return img


def boulders(seed):
    rng = np.random.default_rng(seed)
    img = rgba(quantize(np.full((T, T), 0.15), BOULDER))
    d = ImageDraw.Draw(img)
    for _ in range(4):
        cx, cy = int(rng.integers(2, 14)), int(rng.integers(2, 14))
        r = int(rng.integers(4, 7))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=tuple(BOULDER[2]) + (255,))
        d.ellipse([cx - r + 1, cy - r, cx + r - 2, cy + r - 3], fill=tuple(BOULDER[4]) + (255,))
        d.ellipse([cx - r + 2, cy - r + 1, cx - 1, cy - 1], fill=tuple(BOULDER[6]) + (255,))
    return img


def back(seed):
    rng = np.random.default_rng(seed)
    h = fbm(T, T, 1, 3, rng)
    rows = np.arange(T)[:, None]
    v = 0.45 + (h - 0.5) * 0.5 + 0.08 * np.sin(rows * 0.8 + h * 5)
    return rgba(quantize(np.clip(v, 0, 0.999), BACK))


def deep(seed):
    """Rock far from any edge: darker and quieter, so edges carry the detail."""
    v, _ = texture(ROCK, seed, base=0.27)
    return rgba(quantize(np.clip(v * 0.8, 0, 0.999), ROCK))


# ---------------------------------------------------------------------------
# Props.

def prop(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def c(hexstr, a=255):
    return hex_rgb(hexstr) + (a,)


def props(out):
    out.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(9)
    for i in range(4):  # dry tussock grass on ledge tops
        im = prop(16, 8)
        d = ImageDraw.Draw(im)
        for k in range(int(rng.integers(3, 6))):
            x = int(rng.integers(1, 15))
            hgt = int(rng.integers(3, 7))
            tone = GRASS[int(rng.integers(0, 3))]
            d.line([(x, 7), (x + int(rng.integers(-2, 3)), 7 - hgt)], fill=tone + (255,))
        im.save(out / f"grass_{i}.png")
    for i in range(3):  # pebbles
        im = prop(16, 6)
        d = ImageDraw.Draw(im)
        for k in range(int(rng.integers(2, 5))):
            x, r = int(rng.integers(2, 14)), int(rng.integers(1, 3))
            d.ellipse([x - r, 5 - r * 2, x + r, 5], fill=tuple(ROCK[3]) + (255,))
            d.point((x - r // 2, 5 - r * 2 + 1), fill=tuple(ROCK[6]) + (255,))
        im.save(out / f"pebbles_{i}.png")
    # Giant groundsel: a thick trunk of dead leaves under rosettes.
    im = prop(28, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([12, 16, 15, 47], fill=c("#5a4a38"))
    d.line([(12, 16), (12, 47)], fill=c("#7a6a50"))
    for y in range(20, 46, 3):
        d.line([(10, y), (17, y + 1)], fill=c("#8a7a5a"))
    for cx, cy in ((7, 12), (20, 10), (14, 6)):
        d.ellipse([cx - 7, cy - 4, cx + 7, cy + 4], fill=c("#3e6a2a"))
        d.ellipse([cx - 4, cy - 4, cx + 3, cy + 1], fill=c("#6a9a40"))
        d.line([(cx, cy + 2), (cx, cy + 8)], fill=c("#5a4a38"))
    selective_outline(im, darken=0.35).save(out / "groundsel.png")
    # Lobelia spike.
    im = prop(10, 26)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 3, 9, 25], fill=c("#4a6a3a"))
    for y in range(5, 24, 2):
        d.line([(1, y), (8, y)], fill=c("#6a8a52"))
    d.line([(3, 5), (3, 21)], fill=c("#8aa66a"))
    selective_outline(im, darken=0.35).save(out / "lobelia.png")
    # Cairn.
    im = prop(16, 20)
    d = ImageDraw.Draw(im)
    for y, r in ((17, 6), (12, 5), (8, 4), (5, 3), (2, 2)):
        d.ellipse([8 - r, y - 2, 8 + r, y + 2], fill=c("#7e746b"))
        d.line([(8 - r + 1, y - 2), (8, y - 2)], fill=c("#b8afa4"))
        d.line([(8 - r, y + 1), (8 + r, y + 1)], fill=c("#4e4740"))
    selective_outline(im, darken=0.35).save(out / "cairn.png")
    # Rest stone: a flat seat.
    im = prop(26, 12)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 3, 25, 11], fill=c("#4e463e"))
    d.ellipse([1, 1, 24, 8], fill=c("#7a6e62"))
    d.line([(4, 2), (16, 2)], fill=c("#a89a8a"))
    selective_outline(im, darken=0.35).save(out / "rest_stone.png")
    # Trail sign.
    im = prop(18, 22)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 8, 9, 21], fill=c("#5a3e26"))
    d.rectangle([1, 2, 16, 9], fill=c("#8a6440"))
    d.line([(1, 2), (16, 2)], fill=c("#b08a5e"))
    d.line([(3, 5), (13, 5)], fill=c("#3e2a18"))
    d.line([(3, 7), (10, 7)], fill=c("#3e2a18"))
    selective_outline(im, darken=0.35).save(out / "sign.png")
    # Exit post with a pennant.
    im = prop(14, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 2, 4, 29], fill=c("#6a4a2e"))
    d.polygon([(5, 3), (13, 6), (5, 9)], fill=c("#c8462e"))
    d.line([(5, 3), (13, 6)], fill=c("#e8664a"))
    selective_outline(im, darken=0.35).save(out / "exit_post.png")
    # Tents and the fire come from the world props strip.
    world = Image.open(ROOT / "assets" / "hd2d" / "world" / "props.png")
    world.crop((0, 0, 32, 24)).save(out / "tent_orange.png")
    world.crop((32, 0, 64, 24)).save(out / "tent_blue.png")
    world.crop((64, 0, 192, 24)).save(out / "fire.png")
    # Big foreground boulder silhouette and a background crag, for depth.
    im = prop(64, 40)
    d = ImageDraw.Draw(im)
    d.polygon([(0, 39), (6, 14), (20, 4), (38, 2), (54, 12), (63, 39)], fill=c("#1a1512"))
    d.line([(6, 14), (20, 4), (38, 2)], fill=c("#3a302a"))
    im.save(out / "fg_boulder.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (16 * T, 4 * T), (0, 0, 0, 0))
    for variant in range(2):
        for mask in range(16):
            atlas.paste(rock(mask, variant), (mask * T, variant * T))
    for v in range(2):
        atlas.paste(slope(True, v), (v * T, 2 * T))
        atlas.paste(slope(False, v), ((2 + v) * T, 2 * T))
    for v in range(4):
        atlas.paste(face(FACE, 500 + v), ((4 + v) * T, 2 * T))
        atlas.paste(loose(600 + v), ((8 + v) * T, 2 * T))
        atlas.paste(boulders(700 + v), ((12 + v) * T, 2 * T))
    for v in range(8):
        atlas.paste(back(800 + v), (v * T, 3 * T))
        atlas.paste(deep(900 + v), ((8 + v) * T, 3 * T))
    atlas.save(OUT / "barranco_tiles.png")
    props(OUT / "props")
    print("wrote", OUT / "barranco_tiles.png", "and props")


if __name__ == "__main__":
    main()
