"""
Rock for the Godot climbs, drawn the way pixel artists draw rock rather
than as noise: the mass is broken into blocks (a tileable Voronoi pattern
stretched along the bedding), each block a flat cluster of one tone set by
which way its face tilts to the light (upper left), with a lit rim on the
edges that face the light, a shadowed edge and a dark crack between blocks,
and a slow large-scale swell of light and dark so the tiling never shows.
Ramps are hue-shifted: shadows lean cool (violet or blue), lights warm.

Writes, per palette (barranco basalt, Lava Tower red, summit night):
  scenery/<name>-wall.png        solid rock you look straight into
  scenery/<name>-face.png        rock you can climb: lighter, warmer, with
                                 vertical joints (holds go on top)
  scenery/<name>-wall-deep.png   the back wall behind ledges and faces:
                                 darker, flatter, cooler (it is further)
  terrain/edges-<name>.png       edge overlays for solid rock, 16 masks x 2
                                 variants (column = open-side mask: 1 top,
                                 2 right, 4 bottom, 8 left): a warm lit lip
                                 and a little moss or snow on top, an
                                 outline and an undercut shadow below,
                                 shaded sides, bevelled corners. Drawn over
                                 the wall texture, so edges and interior are
                                 one rock with no seam. Row 2: slopes (0-3)
                                 cut from the same rock, hold overlays for
                                 faces (4-7), loose scree (8-11), scramble
                                 boulders (12-15).

    python3 tools/art/godot_rock.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

from pixel import fbm, hex_rgb

ROOT = Path(__file__).resolve().parents[2]
SCENERY = ROOT / "godot" / "assets" / "scenery"
TERRAIN = ROOT / "godot" / "assets" / "terrain"
N = 256
T = 16

# Seven-step ramps, dark to light, hue-shifted: cool shadows, warm lights.
PALETTES = {
    "barranco": {
        "ramp": ["#17141d", "#24202a", "#352e33", "#4a3f3e", "#605247", "#7c6a56", "#9c8869"],
        "back": "#1c1820", "outline": "#0f0c12", "lip": ["#c8b48e", "#a49072"],
        "top": ["#6f7a3c", "#8c9447", "#55602e"], "snow": False,
    },
    "lava": {
        "ramp": ["#1b1119", "#2c1720", "#43211f", "#5e2f25", "#7a412e", "#9a5a3a", "#bd7c4e"],
        "back": "#1e1219", "outline": "#110a0f", "lip": ["#e0a06a", "#bb8055"],
        "top": ["#7a7a3a", "#94904a", "#5e5c2c"], "snow": False,
    },
    "summit": {
        "ramp": ["#0e1120", "#171c30", "#232a42", "#323b56", "#46506c", "#606b88", "#8590ad"],
        "back": "#101426", "outline": "#080a14", "lip": ["#dfe8f5", "#b6c3d9"],
        "top": ["#e9f0fa", "#cdd8ea", "#aebcd4"], "snow": True,
    },
}


def rgb(h):
    return np.array(hex_rgb(h), dtype=float)


def voronoi(n, count, stretch, rng):
    """Tileable Voronoi on an n x n torus: nearest and second-nearest
    distances, the nearest seed's index, and the direction to the nearest
    seed. `stretch` > 1 widens blocks along x (bedding)."""
    pts = rng.random((count, 2)) * n
    ys, xs = np.mgrid[0:n, 0:n].astype(float)
    d1 = np.full((n, n), 1e9)
    d2 = np.full((n, n), 1e9)
    idx = np.zeros((n, n), dtype=int)
    for i, (px, py) in enumerate(pts):
        dx = xs - px
        dy = ys - py
        dx -= n * np.round(dx / n)
        dy -= n * np.round(dy / n)
        d = np.sqrt((dx / stretch) ** 2 + dy ** 2)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        idx = np.where(closer, i, idx)
        d1 = np.where(closer, d, d1)
    return d1, d2, idx, pts


def rock(pal, seed, back=False, climb=False):
    rng = np.random.default_rng(seed)
    ramp = [rgb(c) for c in pal["ramp"]]
    n = N
    # Big blocks broken by smaller ones: two Voronoi scales.
    d1, d2, idx, pts = voronoi(n, 46, 2.0, rng)
    e1, e2, idx2, _ = voronoi(n, 150, 1.5, rng)
    # Each block's face tilts its own way: its light from the upper left.
    tilt = rng.normal(0, 1, (len(pts), 2))
    light = np.array([-0.7, -0.7])
    face = (tilt @ light) / 2.2
    tone = 0.48 + face[idx] * 0.24
    small = rng.normal(0, 1, idx2.max() + 1)
    tone += small[idx2] * 0.06
    # Large slow swell, so a 256 px tile never repeats visibly.
    swell = fbm(n, n, 2, 3, rng)
    tone += (swell - 0.5) * 0.4
    # Bedding: the mass reads as layered rock without going striped.
    ys = np.arange(n)[:, None]
    tone += 0.05 * np.sin(ys * (np.pi * 2 * 6 / n) + swell * 4)
    # Edges of blocks: cracks, a lit rim toward the light, shadow away.
    border = d2 - d1
    ys2, xs2 = np.mgrid[0:n, 0:n].astype(float)
    sx = pts[idx][:, :, 0]
    sy = pts[idx][:, :, 1]
    vx = xs2 - sx
    vy = ys2 - sy
    vx -= n * np.round(vx / n)
    vy -= n * np.round(vy / n)
    toward = -(vx * light[0] + vy * light[1]) / (np.hypot(vx, vy) + 1e-6)  # >0: edge faces the light
    rim = (border < 2.0) & (border >= 1.0)
    tone = np.where(rim & (toward > 0.25), tone + 0.2, tone)
    tone = np.where(rim & (toward < -0.25), tone - 0.18, tone)
    crack = border < 1.0
    fine = (e2 - e1) < 0.7
    tone = np.where(fine & ~crack, tone - 0.06, tone)
    if climb:
        # Rock you can climb: lighter, cleaner blocks, and long vertical
        # joints (the cracks and edges hands and feet use).
        tone = 0.7 + (tone - 0.5) * 0.65
        rngj = np.random.default_rng(seed + 55)
        for _ in range(14):
            x = int(rngj.integers(0, n))
            y0 = int(rngj.integers(0, n))
            for k in range(int(rngj.integers(30, 90))):
                yy = (y0 + k) % n
                tone[yy, x % n] -= 0.5
                tone[yy, (x + 1) % n] += 0.18
                if rngj.random() < 0.18:
                    x += int(rngj.choice([-1, 1]))
    if back:
        # Further away: flatter and darker.
        tone = 0.26 + (tone - 0.5) * 0.34
    steps = len(ramp)
    i = np.clip(np.round(tone * (steps - 1)), 0, steps - 1).astype(int)
    if back:
        i = np.clip(i, 0, 3)
    out = np.zeros((n, n, 3))
    for k in range(steps):
        out[i == k] = ramp[k]
    out[crack] = rgb(pal["back"]) if back else ramp[0]
    # A few flecks of the lightest tone on lit block faces (grain).
    if climb:
        # Warm the climbable rock toward the lit lip colour.
        out = out * 0.74 + rgb(pal["lip"][1]) * 0.26
    if not back:
        grain = (rng.random((n, n)) < 0.006) & (tone > 0.55) & ~crack
        out[grain] = ramp[-1]
    if pal["snow"] and not back:
        # Rime on upward-facing ledges of blocks.
        top_edge = rim & (vy < 0) & (np.abs(vy) > np.abs(vx) * 0.8)
        frost = top_edge & (border < 1.6) & (rng.random((n, n)) < 0.35)
        out[frost] = rgb(pal["top"][1])
    if back:
        # The back wall sits in the air's colour a little.
        haze = rgb(pal["back"])
        out = out * 0.75 + haze * 0.25
    return Image.fromarray(out.astype(np.uint8), "RGB")


def edges(pal, variant):
    """A transparent overlay per open-side mask, drawn over the wall."""
    rng = np.random.default_rng(700 + variant)
    outline = hex_rgb(pal["outline"])
    lip0, lip1 = hex_rgb(pal["lip"][0]), hex_rgb(pal["lip"][1])
    tops = [hex_rgb(c) for c in pal["top"]]
    sheet = Image.new("RGBA", (16 * T, T), (0, 0, 0, 0))
    for mask in range(16):
        tile = np.zeros((T, T, 4), dtype=np.uint8)
        top, right, bottom, left = mask & 1, mask & 2, mask & 4, mask & 8

        def put(x, y, c, a=255):
            if 0 <= x < T and 0 <= y < T:
                tile[y, x] = (*c, a)

        def shade(x, y, a, dark=True):
            # Darken (or lighten) whatever is under, by alpha.
            if 0 <= x < T and 0 <= y < T and tile[y, x, 3] == 0:
                tile[y, x] = (*(outline if dark else lip0), a)

        if bottom:
            # Undercut: outline, then a shadow fading up into the rock.
            for x in range(T):
                put(x, T - 1, outline)
                shade(x, T - 2, 170)
                shade(x, T - 3, 110)
                shade(x, T - 4, 60)
                shade(x, T - 5, 25)
        if right:
            for y in range(T):
                put(T - 1, y, outline)
                shade(T - 2, y, 120)
                shade(T - 3, y, 55)
        if left:
            for y in range(T):
                put(0, y, outline)
                shade(1, y, 40, dark=False)
        if top:
            for x in range(T):
                put(x, 0, lip0)
                put(x, 1, lip1)
                shade(x, 2, 70, dark=False)
                shade(x, 3, 30, dark=False)
            # Moss, grass or snow along the lip, in clumps.
            x = int(rng.integers(0, 4))
            while x < T:
                w = int(rng.integers(2, 6))
                c = tops[int(rng.integers(0, len(tops)))]
                for k in range(w):
                    put(x + k, 0, c)
                    if pal["snow"] or rng.random() < 0.5:
                        put(x + k, 1, tops[-1] if not pal["snow"] else tops[0])
                x += w + int(rng.integers(3, 8))
        # Bevelled corners where two open sides meet: cut and outline.
        for cond, cx, cy, dx, dy in ((top and left, 0, 0, 1, 1), (top and right, T - 1, 0, -1, 1),
                                     (bottom and left, 0, T - 1, 1, -1), (bottom and right, T - 1, T - 1, -1, -1)):
            if not cond:
                continue
            for k, w in enumerate((3, 2, 1)):
                for i in range(w):
                    tile[cy + dy * k, cx + dx * i] = (0, 0, 0, 0)
                # The new outline steps along the cut.
                put(cx + dx * w, cy + dy * k, lip0 if (top and dy == 1) else outline)
        sheet.paste(Image.fromarray(tile, "RGBA"), (mask * T, 0))
    return sheet


def slopes_and_faces(pal, wall, seed):
    """Row 2 of the edges atlas: slopes cut from the wall texture (0-1 rising
    right, 2-3 rising left), then climbable faces (4-7): the same rock a
    step lighter and warmer, with clear holds: little ledges lit on top,
    shadowed under, a dab of chalk on some."""
    rng = np.random.default_rng(seed)
    src = np.array(wall.convert("RGB")).astype(float)
    outline = np.array(hex_rgb(pal["outline"]), dtype=float)
    lip0 = np.array(hex_rgb(pal["lip"][0]), dtype=float)
    lip1 = np.array(hex_rgb(pal["lip"][1]), dtype=float)
    row = np.zeros((T, 16 * T, 4), dtype=np.uint8)
    for k in range(4):
        up_right = k < 2
        ox, oy = int(rng.integers(0, N - T)), int(rng.integers(0, N - T))
        tile = src[oy:oy + T, ox:ox + T]
        for y in range(T):
            for x in range(T):
                surface = (T - 1 - x) if up_right else x
                if y < surface:
                    continue
                c = tile[y, x]
                if y == surface:
                    c = lip0
                elif y == surface + 1:
                    c = lip1
                row[y, k * T + x] = (*c.astype(int), 255)
    # 4-7: holds, drawn over the face texture: little ledges lit on top,
    # shadowed under, a dab of chalk on some.
    for k in range(4):
        cells = [(2, 3), (9, 6), (4, 11), (11, 13)] if k % 2 == 0 else [(8, 2), (2, 7), (10, 10), (5, 14)]
        for hx, hy in cells:
            hx = (hx + int(rng.integers(-1, 2))) % (T - 4)
            w = int(rng.integers(3, 5))
            for i in range(w):
                c = lip0 if 0 < i < w - 1 else lip1
                row[hy - 1, (4 + k) * T + hx + i] = (*c.astype(int), 255)
                row[hy, (4 + k) * T + hx + i] = (*outline.astype(int), 200)
            if rng.random() < 0.5:
                row[hy - 2, (4 + k) * T + hx + 1] = (240, 236, 226, 150)
    ramp = [np.array(hex_rgb(c), dtype=float) for c in pal["ramp"]]
    # 8-11: loose scree: a pile of small stones, each lit on its top left
    # and outlined, darker gaps between.
    for k in range(4):
        tile = np.zeros((T, T, 3)) + ramp[1]
        for _ in range(14):
            cx, cy = rng.integers(0, T), rng.integers(0, T)
            r = float(rng.uniform(1.4, 2.8))
            for y in range(T):
                for x in range(T):
                    dx = (x - cx + T // 2) % T - T // 2
                    dy = (y - cy + T // 2) % T - T // 2
                    d = (dx * dx + dy * dy) ** 0.5
                    if d <= r:
                        tile[y, x] = ramp[5] if (dx + dy) < -r * 0.5 else ramp[3 + int(rng.integers(0, 2))]
                    elif d <= r + 0.7 and (dx + dy) > 0:
                        tile[y, x] = outline
        row[:, (8 + k) * T:(9 + k) * T] = np.dstack([tile, np.full((T, T), 255)]).astype(np.uint8)
    # 12-15: scramble, a jumble of boulders: round clusters, lit top left,
    # outlined, the gaps between them in shadow.
    for k in range(4):
        tile = np.zeros((T, T, 3)) + ramp[1]
        for _ in range(4):
            cx, cy = rng.integers(1, T - 1), rng.integers(1, T - 1)
            r = int(rng.integers(4, 7))
            for y in range(T):
                for x in range(T):
                    # Wrap so the boulders tile.
                    dx = (x - cx + T // 2) % T - T // 2
                    dy = (y - cy + T // 2) % T - T // 2
                    d = (dx * dx + dy * dy) ** 0.5
                    if d <= r:
                        lightness = 4 if (dx + dy) < -r * 0.4 else (3 if d < r * 0.7 else 2)
                        tile[y, x] = ramp[lightness]
                    elif d <= r + 0.8:
                        tile[y, x] = outline
        row[:, (12 + k) * T:(13 + k) * T] = np.dstack([tile, np.full((T, T), 255)]).astype(np.uint8)
    return Image.fromarray(row, "RGBA")


def main():
    SCENERY.mkdir(parents=True, exist_ok=True)
    TERRAIN.mkdir(parents=True, exist_ok=True)
    for i, (name, pal) in enumerate(PALETTES.items()):
        rock(pal, 101 + i).save(SCENERY / f"{name}-wall.png")
        rock(pal, 101 + i, back=True).save(SCENERY / f"{name}-wall-deep.png")
        rock(pal, 151 + i, climb=True).save(SCENERY / f"{name}-face.png")
        wall = rock(pal, 101 + i)
        atlas = Image.new("RGBA", (16 * T, 3 * T), (0, 0, 0, 0))
        for v in range(2):
            atlas.paste(edges(pal, v + i * 2), (0, v * T))
        atlas.paste(slopes_and_faces(pal, wall, 900 + i), (0, 2 * T))
        atlas.save(TERRAIN / f"edges-{name}.png")
        print("wrote", name)


if __name__ == "__main__":
    main()
