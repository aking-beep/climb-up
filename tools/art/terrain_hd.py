"""
The climbs' terrain in high resolution, for a polished mobile look rather
than pixel art: 64 px per 16 px tile (4x), shown at a quarter scale with
smooth filtering, so a phone draws rock at its full resolution.

The style follows what reads well on a phone (Alto's Odyssey, Supercell's
games): big simple shapes, smooth gradients instead of dithering, a limited
palette per area, soft light from the upper left with warm lights and cool
shadows, soft ambient occlusion in cracks and under ledges, and depth from
layering (the back wall is darker, hazier and softly blurred).

Per palette (barranco, lava, summit), into godot/assets/terrain/hd/:
  <name>-solid.png  1024 x 1024: solid rock you look into
  <name>-back.png   1024 x 1024: the back wall, further away
  <name>-face.png   1024 x 1024: rock you can climb, lighter, with joints
  <name>-edges.png  16 x 3 tiles of 64: rows 0-1 edge overlays by open-side
                    mask (1 top, 2 right, 4 bottom, 8 left): a rounded lip
                    with a grass, moss or snow cap, soft shadow under
                    ledges, outlines; row 2: slopes (0-3), face holds (4-7),
                    scree (8-11), boulders (12-15)
And hazards-hd.png (4 x 2 tiles): ice (row 0), slabs whole (row 1, 0-1)
and breaking (2-3).

    python3 tools/art/terrain_hd.py
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from pixel import fbm, hex_rgb

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "assets" / "terrain" / "hd"
S = 4            # texels per world pixel
T = 16 * S       # one tile
N = 256 * S      # the repeating texture

PALETTES = {
    "barranco": {
        "ramp": ["#1d1820", "#2b2428", "#3d3430", "#544638", "#6e5c46", "#8c7656", "#ad9470"],
        "haze": "#3a3438", "outline": "#18121a",
        "lip": "#d8c49a", "cap": ["#5f7d36", "#7f9e44", "#a6c25a"], "snow": False,
    },
    "lava": {
        "ramp": ["#201218", "#33171c", "#4d2220", "#6c3326", "#8c4830", "#ad643c", "#d08a56"],
        "haze": "#3a2024", "outline": "#160b10",
        "lip": "#f0b47a", "cap": ["#6b7a32", "#8b9a40", "#b4c058"], "snow": False,
    },
    "summit": {
        "ramp": ["#0f1324", "#181e36", "#252d4a", "#34405e", "#4a5776", "#66748f", "#8c98b2"],
        "haze": "#1c2238", "outline": "#0a0c18",
        "lip": "#e6eef8", "cap": ["#c3d0e4", "#e2eaf6", "#ffffff"], "snow": True,
    },
}


def rgb(h):
    return np.array(hex_rgb(h), dtype=float)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def ramp_color(ramp, tone):
    """Continuous colour along the ramp (no banding, no dither)."""
    cols = np.array([rgb(c) for c in ramp])
    pos = np.linspace(0, 1, len(ramp))
    t = np.clip(tone, 0, 1)
    return np.dstack([np.interp(t, pos, cols[:, k]) for k in range(3)])


def voronoi(n, count, stretch, rng):
    pts = rng.random((count, 2)) * n
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    d1 = np.full((n, n), 1e9, np.float32)
    d2 = np.full((n, n), 1e9, np.float32)
    idx = np.zeros((n, n), np.int32)
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


def rock(pal, seed, kind="solid"):
    rng = np.random.default_rng(seed)
    n = N
    d1, d2, idx, pts = voronoi(n, 46, 2.0, rng)
    e1, e2, idx2, _ = voronoi(n, 150, 1.5, rng)
    light = np.array([-0.7, -0.7])
    tilt = rng.normal(0, 1, (len(pts), 2))
    face = (tilt @ light) / 2.2
    tone = 0.48 + face[idx] * 0.22
    tone += rng.normal(0, 1, idx2.max() + 1)[idx2] * 0.03
    # A gentle gradient across each block toward the light: rounded, not flat.
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    vx = xs - pts[idx][:, :, 0]
    vy = ys - pts[idx][:, :, 1]
    vx -= n * np.round(vx / n)
    vy -= n * np.round(vy / n)
    dist = np.hypot(vx, vy) + 1e-3
    tone += (-(vx * light[0] + vy * light[1]) / 90.0) * 0.06
    swell = fbm(n, n, 2, 3, rng)
    tone += (swell - 0.5) * 0.36
    # Bevels: lit on edges facing the light, shaded on the others, soft.
    border = d2 - d1
    toward = -(vx * light[0] + vy * light[1]) / dist
    bevel = 1 - smoothstep(2.0, 12.0, border)
    tone += bevel * np.clip(toward, 0, 1) * 0.2
    tone -= bevel * np.clip(-toward, 0, 1) * 0.2
    # Ambient occlusion into the cracks, and the cracks themselves.
    tone -= (1 - smoothstep(2.0, 9.0, border)) * 0.08
    fine = 1 - smoothstep(0.5, 2.5, e2 - e1)
    tone -= fine * 0.05
    if kind == "face":
        tone = 0.7 + (tone - 0.5) * 0.6
        rj = np.random.default_rng(seed + 55)
        joints = np.zeros((n, n), np.float32)
        for _ in range(14):
            x = float(rj.integers(0, n))
            y0 = int(rj.integers(0, n))
            for k in range(int(rj.integers(120, 360))):
                yy = (y0 + k) % n
                x += rj.normal(0, 0.35)
                xi = int(x) % n
                joints[yy, xi] = 1
                joints[yy, (xi + 1) % n] = max(joints[yy, (xi + 1) % n], 0.5)
        tone -= joints * 0.35
        tone += np.roll(joints, 2, axis=1) * 0.12
    if kind == "back":
        tone = 0.27 + (tone - 0.5) * 0.4
    col = ramp_color(pal["ramp"], tone)
    crack = 1 - smoothstep(1.2, 3.2, border)
    col = col * (1 - crack[..., None] * 0.85) + rgb(pal["outline"]) * crack[..., None] * 0.85
    if kind == "face":
        col = col * 0.78 + rgb(pal["lip"]) * 0.22
    # A whisper of grain so it reads as stone, not plastic.
    col *= 1 + (rng.random((n, n, 1)) - 0.5) * 0.03
    if pal["snow"] and kind != "back":
        frost = bevel * smoothstep(0.2, 0.8, -vy / dist) * 0.9
        col = col * (1 - frost[..., None] * 0.55) + rgb(pal["cap"][1]) * frost[..., None] * 0.55
    if kind == "back":
        col = col * 0.78 + rgb(pal["haze"]) * 0.22
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGB")
    if kind == "back":
        # Further away: a soft focus, like a camera's.
        tiled = Image.new("RGB", (n * 3, n * 3))
        for i in range(3):
            for j in range(3):
                tiled.paste(img, (i * n, j * n))
        img = tiled.filter(ImageFilter.GaussianBlur(2.2)).crop((n, n, 2 * n, 2 * n))
    return img


# --- Edges, slopes and the rest --------------------------------------------

def layer(alpha, color):
    out = np.zeros((T, T, 4), np.float32)
    out[..., :3] = color
    out[..., 3] = np.clip(alpha, 0, 1) * 255
    return out


def over(dst, src):
    a = src[..., 3:4] / 255.0
    b = dst[..., 3:4] / 255.0
    o = a + b * (1 - a)
    rgbv = (src[..., :3] * a + dst[..., :3] * b * (1 - a)) / np.maximum(o, 1e-6)
    return np.concatenate([rgbv, o * 255], axis=-1)


def cap(pal, rng, w=T, h=30):
    """A rounded cap of grass, moss or snow along the top lip, as clumps."""
    k = 4
    im = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    dark, mid, light = [tuple(int(v) for v in rgb(c)) for c in pal["cap"]]
    outline = tuple(int(v) for v in rgb(pal["outline"]))
    x = -int(rng.integers(4, 12))
    while x < w:
        r = int(rng.integers(10, 15)) if not pal["snow"] else int(rng.integers(13, 19))
        cy = 10
        d.ellipse([(x - r) * k - 6, (cy - r * 0.55) * k - 6, (x + r) * k + 6, (cy + r * 0.55) * k + 6], fill=outline + (255,))
        d.ellipse([(x - r) * k, (cy - r * 0.55) * k, (x + r) * k, (cy + r * 0.55) * k], fill=mid + (255,))
        d.ellipse([(x - r * 0.75) * k, (cy - r * 0.5) * k, (x + r * 0.2) * k, (cy - r * 0.05) * k], fill=light + (255,))
        d.ellipse([(x - r * 0.2) * k, (cy + r * 0.05) * k, (x + r * 0.9) * k, (cy + r * 0.5) * k], fill=dark + (255,))
        if not pal["snow"]:
            for _ in range(3):
                bx = x + float(rng.uniform(-r, r))
                d.line([(bx * k, (cy - r * 0.3) * k), ((bx + rng.uniform(-3, 3)) * k, (cy - r * 0.3 - rng.uniform(4, 9)) * k)], fill=dark + (255,), width=6)
        x += int(r * 1.4)
    return np.array(im.resize((w, h), Image.LANCZOS)).astype(np.float32)


def edge_tile(pal, mask, rng):
    top, right, bottom, left = mask & 1, mask & 2, mask & 4, mask & 8
    ys, xs = np.mgrid[0:T, 0:T].astype(np.float32)
    out = np.zeros((T, T, 4), np.float32)
    outline = rgb(pal["outline"])
    if bottom:
        # Soft shadow up into the rock under a ledge, then the outline.
        out = over(out, layer((1 - smoothstep(0, 26, (T - 1) - ys)) * 0.6, outline))
        out = over(out, layer(smoothstep(T - 5, T - 2.5, ys), outline))
    if right:
        out = over(out, layer((1 - smoothstep(0, 16, (T - 1) - xs)) * 0.4, outline))
        out = over(out, layer(smoothstep(T - 5, T - 2.5, xs), outline))
    if left:
        out = over(out, layer((1 - smoothstep(0, 12, xs)) * 0.18, rgb(pal["lip"])))
        out = over(out, layer(1 - smoothstep(1.5, 4, xs), outline))
    if top:
        # A lit, rounded lip.
        out = over(out, layer((1 - smoothstep(0, 18, ys)) * 0.42, rgb(pal["lip"])))
        out = over(out, layer(1 - smoothstep(2, 5, ys), rgb(pal["lip"])))
        c = cap(pal, rng)
        pad = np.zeros((T, T, 4), np.float32)
        pad[0:c.shape[0] - 3] = c[3:]
        out = over(out, pad)
    # Rounded corners: an outline arc where two open sides meet.
    for cond, cx, cy in ((bottom and left, 10, T - 10), (bottom and right, T - 10, T - 10), (top and right, T - 10, 10), (top and left, 10, 10)):
        if not cond:
            continue
        r = np.hypot(xs - cx, ys - cy)
        outside = ((xs - cx) * (1 if cx > T / 2 else -1) > 0) & ((ys - cy) * (1 if cy > T / 2 else -1) > 0)
        ring = outside & (r > 7.5)
        out = over(out, layer(ring * 1.0, outline))
    return np.clip(out, 0, 255).astype(np.uint8)


def row2(pal, solid, rng):
    src = np.array(solid).astype(np.float32)
    row = np.zeros((T, 16 * T, 4), np.float32)
    ys, xs = np.mgrid[0:T, 0:T].astype(np.float32)
    outline = rgb(pal["outline"])
    lip = rgb(pal["lip"])
    for k in range(4):
        up_right = k < 2
        ox, oy = int(rng.integers(0, N - T)), int(rng.integers(0, N - T))
        tile = np.concatenate([src[oy:oy + T, ox:ox + T], np.full((T, T, 1), 255.0)], axis=-1)
        surface = (T - 1 - xs) if up_right else xs
        alpha = smoothstep(-0.8, 0.8, ys - surface)
        tile[..., 3] = alpha * 255
        tile = over(tile, layer(alpha * (1 - smoothstep(0, 14, ys - surface)) * 0.5, lip))
        tile = over(tile, layer(alpha * (1 - smoothstep(1.5, 4.5, ys - surface)), lip))
        row[:, k * T:(k + 1) * T] = tile
    # Holds on a face: a rounded ledge, lit top, dark undercut, chalk.
    for k in range(4):
        im = Image.new("RGBA", (T * 4, T * 4), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        spots = [(10, 14), (38, 26), (16, 44), (44, 54)] if k % 2 == 0 else [(34, 10), (8, 30), (40, 40), (20, 56)]
        for hx, hy in spots:
            hx += int(rng.integers(-3, 4))
            w = int(rng.integers(12, 18))
            q = 4
            d.rounded_rectangle([hx * q - 8, (hy - 1) * q - 8, (hx + w) * q + 8, (hy + 5) * q + 8], radius=16, fill=tuple(int(v) for v in outline) + (230,))
            d.rounded_rectangle([hx * q, (hy - 1) * q, (hx + w) * q, (hy + 3) * q], radius=12, fill=tuple(int(v) for v in lip) + (255,))
            d.rounded_rectangle([hx * q + 6, (hy + 2) * q, (hx + w) * q - 6, (hy + 5) * q], radius=10, fill=(30, 20, 18, 255))
            if rng.random() < 0.6:
                for j in range(3):
                    cx = (hx + 2 + j * 4) * q
                    d.ellipse([cx, (hy - 4) * q, cx + 12, (hy - 2) * q], fill=(252, 250, 244, 200))
        row[:, (4 + k) * T:(5 + k) * T] = np.array(im.resize((T, T), Image.LANCZOS)).astype(np.float32)
    ramp = [rgb(c) for c in pal["ramp"]]
    for k, (count, rmin, rmax) in enumerate([(16, 5, 9)] * 4 + [(4, 16, 24)] * 4):
        im = Image.new("RGBA", (T * 4, T * 4), tuple(int(v) for v in ramp[1]) + (255,))
        d = ImageDraw.Draw(im)
        for _ in range(count):
            cx, cy = int(rng.integers(0, T)), int(rng.integers(0, T))
            r = float(rng.uniform(rmin, rmax))
            for dx in (-T, 0, T):
                for dy in (-T, 0, T):
                    x, y = (cx + dx) * 4, (cy + dy) * 4
                    rr = r * 4
                    d.ellipse([x - rr - 6, y - rr - 6, x + rr + 6, y + rr + 6], fill=tuple(int(v) for v in outline) + (255,))
                    d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=tuple(int(v) for v in ramp[3]) + (255,))
                    d.ellipse([x - rr * 0.8, y - rr * 0.85, x + rr * 0.35, y + rr * 0.2], fill=tuple(int(v) for v in ramp[4]) + (255,))
                    d.ellipse([x - rr * 0.55, y - rr * 0.65, x - rr * 0.1, y - rr * 0.3], fill=tuple(int(v) for v in ramp[6]) + (255,))
        row[:, (8 + k) * T:(9 + k) * T] = np.array(im.resize((T, T), Image.LANCZOS)).astype(np.float32)
    return np.clip(row, 0, 255).astype(np.uint8)


def hazards():
    rng = np.random.default_rng(5)
    atlas = np.zeros((2 * T, 4 * T, 4), np.uint8)
    ys, xs = np.mgrid[0:T, 0:T].astype(np.float32)
    for k in range(4):
        # Ice: glassy pale blue, a gloss streak, a darker rim.
        base = np.dstack([np.full((T, T), 168.0), np.full((T, T), 210.0), np.full((T, T), 238.0)])
        base -= (ys / T)[..., None] * np.array([40, 30, 10])
        streak = 1 - smoothstep(1.5, 4.0, np.abs((xs + ys * 0.6) - (18 + k * 9) % T))
        base += streak[..., None] * 50
        base = base * (1 + (rng.random((T, T, 1)) - 0.5) * 0.04)
        tile = np.concatenate([np.clip(base, 0, 255), np.full((T, T, 1), 235.0)], axis=-1)
        tile[:4, :, :3] = [236, 246, 255]
        atlas[0:T, k * T:(k + 1) * T] = tile.astype(np.uint8)
    for k in range(4):
        breaking = k >= 2
        im = Image.new("RGBA", (T * 4, T * 4), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([4, 4, T * 4 - 4, T * 4 - 4], radius=18, fill=(30, 22, 24, 255))
        d.rounded_rectangle([12, 10, T * 4 - 12, T * 4 - 14], radius=14, fill=(132, 112, 92, 255))
        d.rounded_rectangle([18, 14, T * 4 - 40, 60], radius=10, fill=(168, 146, 118, 255))
        pts = [(40 + k * 20, 12), (90, 70), (70 + k * 10, 140), (120, 200), (110, 250)]
        d.line(pts, fill=(36, 26, 24, 255), width=10 if breaking else 6, joint="curve")
        if breaking:
            d.line([(90, 70), (200, 110), (230, 180)], fill=(36, 26, 24, 255), width=10, joint="curve")
            d.line([(70, 140), (20, 190)], fill=(36, 26, 24, 255), width=8)
        atlas[T:2 * T, k * T:(k + 1) * T] = np.array(im.resize((T, T), Image.LANCZOS))
    return Image.fromarray(atlas, "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for i, (name, pal) in enumerate(PALETTES.items()):
        solid = rock(pal, 101 + i, "solid")
        solid.save(OUT / f"{name}-solid.png")
        rock(pal, 101 + i, "back").save(OUT / f"{name}-back.png")
        rock(pal, 151 + i, "face").save(OUT / f"{name}-face.png")
        rng = np.random.default_rng(700 + i)
        atlas = np.zeros((3 * T, 16 * T, 4), np.uint8)
        for v in range(2):
            for mask in range(16):
                atlas[v * T:(v + 1) * T, mask * T:(mask + 1) * T] = edge_tile(pal, mask, rng)
        atlas[2 * T:3 * T] = row2(pal, solid, rng)
        Image.fromarray(atlas, "RGBA").save(OUT / f"{name}-edges.png")
        print("wrote", name)
    hazards().save(OUT / "hazards-hd.png")
    print("wrote hazards-hd")


if __name__ == "__main__":
    main()
