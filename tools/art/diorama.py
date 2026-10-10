"""
HD-2D world plates for the expedition (strategy) screen: one diorama per
Kilimanjaro zone, seen from a high three-quarter camera like a model railway.

A generated height field (a valley with the trail up its floor, crags and
ridges either side, the ground climbing away from the camera) is ray-cast
per pixel, lit from the upper left with cast shadows and cavity shading,
coloured per zone, and dressed with pixel-art props (trees, groundsels,
boulders) billboarded at their depth. The sky is left transparent: the app
paints it per time of day, with the distant Kibo layer behind.

Writes, per zone, to assets/hd2d/world/:
    <zone>.webp   the plate (RGBA)
    <zone>.json   where the trail, the camp and the light sources fall on it,
                  in plate-relative coordinates, for placing the party
Also writes props.png (tents and campfire frames), fog.png (tiling mist),
and map.png (the parchment route map).

    python3 tools/art/diorama.py            # all zones
    python3 tools/art/diorama.py snow 0.5   # one zone at half size, to iterate
"""

import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

from pixel import OUT, fbm, hex_rgb, selective_outline

W, H = 960, 768
WORLD = OUT / "world"

# World: x across (-64..64), z away from the camera (0..256), y up.
NX, NZ = 512, 1024
X0, X1, Z0, Z1 = -64.0, 64.0, 0.0, 256.0
DX = (X1 - X0) / (NX - 1)
DZ = (Z1 - Z0) / (NZ - 1)

CAM = np.array([0.0, 40.0, -16.0])
PITCH = math.radians(-21)
VFOV = math.radians(48)
SUN = np.array([-0.55, 0.75, 0.35])
SUN = SUN / np.linalg.norm(SUN)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    """Blend; a per-cell weight is spread over colour channels when needed."""
    t = np.asarray(t, dtype=float)
    colour = np.shape(a)[-1:] == (3,) or np.shape(b)[-1:] == (3,)
    if t.ndim and colour:
        t = t[..., None]
    return a * (1 - t) + b * t


def col(h):
    return np.array(hex_rgb(h), dtype=float) / 255.0


def trail_x(z, zone):
    s = zone["seed"]
    return 6.5 * np.sin(z / 21.0 + s) + 3.0 * np.sin(z / 8.5 + 2 * s) * smoothstep(10, 40, z)


ZONES = {
    "rainforest": {
        "seed": 1.3,
        "grade": 0.05,
        "walls": 34.0,
        "open": 9.0,
        "crag": 0.45,
        "canopy": 0.8,
        "props": [("tree", 0.008, 4.5), ("fern", 0.006, 2.2)],
    },
    "moorland": {
        "seed": 2.1,
        "grade": 0.05,
        "walls": 26.0,
        "open": 13.0,
        "crag": 0.7,
        "canopy": 0.0,
        "props": [("groundsel", 0.0012, 2.6), ("lobelia", 0.0010, 2.2), ("boulder", 0.0005, 2.4), ("heather", 0.005, 2.2)],
    },
    "desert": {
        "seed": 3.4,
        "grade": 0.06,
        "walls": 30.0,
        "open": 12.0,
        "crag": 1.0,
        "canopy": 0.0,
        "props": [("boulder", 0.0011, 2.4), ("cairn", 0.0003, 3.0)],
    },
    "snow": {
        "seed": 4.6,
        "grade": 0.07,
        "walls": 40.0,
        "open": 8.0,
        "crag": 1.0,
        "canopy": 0.0,
        "props": [("boulder", 0.0008, 2.4)],
    },
}


# ---------------------------------------------------------------------------
# Height field and its colour.


def terrain(zone):
    rng = np.random.default_rng(int(zone["seed"] * 1000))
    xs = np.linspace(X0, X1, NX)
    zs = np.linspace(Z0, Z1, NZ)
    X, Z = np.meshgrid(xs, zs)
    px = trail_x(Z, zone)
    d = np.abs(X - px)

    n1 = fbm(NX, NZ, 3, 4, rng, wrap=False)
    n2 = fbm(NX, NZ, 14, 4, rng, wrap=False)
    ridged = 1 - np.abs(2 * fbm(NX, NZ, 5, 4, rng, wrap=False) - 1)
    fine = fbm(NX, NZ, 64, 3, rng, wrap=False)

    base = Z * zone["grade"]
    open_ = zone["open"] * (0.8 + 0.5 * n1)
    # Low near the camera so they frame the view rather than block it.
    near = 0.35 + 0.65 * smoothstep(10, 140, Z)
    walls = zone["walls"] * smoothstep(open_, open_ + 26, d) * (0.55 + 0.7 * n1) * near
    crags = zone["crag"] * 7.0 * ridged**2.5 * smoothstep(open_ * 0.6, open_ + 12, d)
    rolling = 2.2 * (n2 - 0.5) + 0.35 * (fine - 0.5)
    h = base + walls + crags + rolling

    # Tree crowns as bumps on the rainforest walls (they read as canopy).
    if zone["canopy"] > 0:
        crowns = fbm(NX, NZ, 90, 2, rng, wrap=False)
        h += zone["canopy"] * np.clip(crowns - 0.42, 0, None) * 3 * smoothstep(3, 7, d)

    # The trail: a shelf cut along the valley floor, slightly sunk.
    trail_h = base + 2.2 * (n2 - 0.5)
    shelf = 1 - smoothstep(1.4, 5.5, d)
    h = mix(h, trail_h, shelf) - 0.18 * (1 - smoothstep(0.4, 1.3, d))

    # A level camp terrace beside the trail.
    cz = 46.0
    cx = float(trail_x(np.array(cz), zone)) + 7.5
    camp = 1 - smoothstep(4.0, 8.0, np.hypot(X - cx, (Z - cz) * 0.9))
    h = mix(h, cz * zone["grade"] + 0.2, camp)

    return {
        "X": X,
        "Z": Z,
        "h": h,
        "d": d,
        "n1": n1,
        "n2": n2,
        "fine": fine,
        "ridged": ridged,
        "camp": (cx, cz),
        "base": base,
    }


def normals(h):
    gx = np.gradient(h, DX, axis=1)
    gz = np.gradient(h, DZ, axis=0)
    n = np.dstack([-gx, np.ones_like(h), -gz])
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def shadows(h):
    """Cast shadows by marching each cell toward the sun over the grid."""
    lit = np.ones_like(h)
    horiz = math.hypot(SUN[0], SUN[2])
    rise = SUN[1] / horiz
    step = 0.6
    sx, sz = SUN[0] / horiz * step, SUN[2] / horiz * step
    zi, xi = np.mgrid[0:NZ, 0:NX].astype(float)
    for k in range(1, 90):
        x = xi + k * sx / DX
        z = zi + k * sz / DZ
        inside = (x >= 0) & (x < NX - 1) & (z >= 0) & (z < NZ - 1)
        hx = np.clip(x, 0, NX - 1).astype(int)
        hz = np.clip(z, 0, NZ - 1).astype(int)
        blocked = inside & (h[hz, hx] > h + rise * k * step + 0.3)
        lit = np.where(blocked, np.minimum(lit, 0.0), lit)
    return lit


def box_blur(a, r):
    """Three box passes per axis: close to a Gaussian, in plain numpy."""
    out = a.astype(float)
    for axis in (0, 1):
        for _ in range(3):
            pad = [(0, 0), (0, 0)]
            pad[axis] = (r + 1, r)
            c = np.cumsum(np.pad(out, pad, mode="edge"), axis=axis)
            hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
            lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
            out = (hi - lo) / (2 * r + 1)
    return out


def cavity(h):
    blur = box_blur(h, 6)
    return np.clip((h - blur) * 0.22, -0.35, 0.3)


def albedo(zone_name, t, n):
    """Ground colour per cell from height, slope, noise and the trail."""
    slope = 1 - n[:, :, 1]  # 0 flat .. 1 vertical
    rel = t["h"] - t["base"]  # height above the trail line
    d = t["d"]
    trail = 1 - smoothstep(0.9, 2.0, d + (t["fine"] - 0.5) * 1.2)
    edge = (1 - smoothstep(2.0, 3.6, d)) - trail
    f, n1, n2 = t["fine"], t["n1"], t["n2"]
    cx, cz = t["camp"]
    campd = np.hypot(t["X"] - cx, t["Z"] - cz)

    if zone_name == "rainforest":
        a = mix(col("#2f5a22"), col("#4f7f2c"), f)
        a = mix(a, col("#1d3d1a"), smoothstep(0.3, 0.7, n2))
        a = mix(a, col("#6f9a3a"), smoothstep(0.62, 0.8, f) * 0.6)
        a = mix(a, col("#5a5040"), smoothstep(0.45, 0.8, slope))
        dirt = mix(col("#8a5a36"), col("#a4703f"), f)
    elif zone_name == "moorland":
        a = mix(col("#6d6a3a"), col("#8c7c46"), f)
        a = mix(a, col("#5a4a3c"), smoothstep(0.45, 0.75, n2))
        a = mix(a, col("#7a5a5a"), smoothstep(0.7, 0.85, f) * 0.5)  # heather
        a = mix(a, col("#6b6258"), smoothstep(0.35, 0.7, slope))
        dirt = mix(col("#a08868"), col("#b8a07c"), f)
    elif zone_name == "desert":
        a = mix(col("#7c6e60"), col("#9a8a78"), f)
        a = mix(a, col("#5c5048"), smoothstep(0.4, 0.75, n2))
        a = mix(a, col("#4a403a"), smoothstep(0.35, 0.7, slope))
        a = mix(a, col("#a8826a"), smoothstep(0.7, 0.9, n1) * 0.5)  # red scree
        dirt = mix(col("#b4a48e"), col("#c8b8a0"), f)
    else:  # snow
        snow = mix(col("#e8eef4"), col("#ffffff"), f)
        snow = mix(snow, col("#c8d6e6"), smoothstep(0.4, 0.8, n2) * 0.6)
        rock = mix(col("#4e4a54"), col("#6e6874"), f)
        ice = mix(col("#9cc4e0"), col("#d4eaf6"), f)
        cover = smoothstep(0.62, 0.42, slope + (f - 0.5) * 0.25)
        a = mix(rock, snow, cover)
        # Steep, high walls are glacier ice cliffs.
        ice_wall = smoothstep(0.45, 0.6, slope) * smoothstep(12, 20, rel) * smoothstep(0.4, 0.6, n1)
        a = mix(a, ice, ice_wall)
        dirt = mix(col("#cfd6de"), col("#b8c0ca"), f)  # trodden snow

    a = mix(a, dirt * 0.85, edge.clip(0, 1) * 0.5)
    a = mix(a, dirt, trail)
    camp_ground = 1 - smoothstep(4.0, 6.5, campd)
    a = mix(a, dirt * 0.95, camp_ground * 0.6)
    return a


# ---------------------------------------------------------------------------
# Camera and ray casting.


def camera_basis():
    fwd = np.array([0.0, math.sin(PITCH), math.cos(PITCH)])
    right = np.array([1.0, 0.0, 0.0])
    up = np.cross(fwd, right)
    return fwd, right, up


def rays(w, h):
    fwd, right, up = camera_basis()
    tv = math.tan(VFOV / 2)
    th = tv * w / h
    u = (np.arange(w) + 0.5) / w * 2 - 1
    v = 1 - (np.arange(h) + 0.5) / h * 2
    U, V = np.meshgrid(u, v)
    d = fwd[None, None, :] + U[..., None] * th * right + V[..., None] * tv * up
    return d / np.linalg.norm(d, axis=2, keepdims=True)


def project(p, w, h):
    """World point(s) to plate pixels, and depth along the view axis."""
    fwd, right, up = camera_basis()
    rel = np.asarray(p, dtype=float) - CAM
    zc = rel @ fwd
    xc = rel @ right
    yc = rel @ up
    tv = math.tan(VFOV / 2)
    th = tv * w / h
    sx = (xc / (zc * th) + 1) / 2 * w
    sy = (1 - yc / (zc * tv)) / 2 * h
    return sx, sy, zc


def height_at(hf, x, z):
    fx = (x - X0) / DX
    fz = (z - Z0) / DZ
    inside = (fx >= 0) & (fx < NX - 1) & (fz >= 0) & (fz < NZ - 1)
    fx = np.clip(fx, 0, NX - 1.001)
    fz = np.clip(fz, 0, NZ - 1.001)
    x0 = fx.astype(int)
    z0 = fz.astype(int)
    tx = fx - x0
    tz = fz - z0
    a = hf[z0, x0]
    b = hf[z0, x0 + 1]
    c = hf[z0 + 1, x0]
    d = hf[z0 + 1, x0 + 1]
    return (a * (1 - tx) + b * tx) * (1 - tz) + (c * (1 - tx) + d * tx) * tz, inside


def raycast(hf, w, h):
    dirs = rays(w, h).reshape(-1, 3)
    n = dirs.shape[0]
    t = np.full(n, 4.0)
    hit = np.zeros(n, dtype=bool)
    alive = np.arange(n)
    for _ in range(1400):
        if alive.size == 0:
            break
        dd = dirs[alive]
        tt = t[alive]
        p = CAM + dd * tt[:, None]
        g, inside = height_at(hf, p[:, 0], p[:, 2])
        below = inside & (p[:, 1] <= g)
        out = (~inside & (tt > 30)) | (tt > 420)
        if below.any():
            idx = alive[below]
            # Refine between the last two samples.
            lo = t[idx] - np.maximum(0.06, t[idx] * 0.006)
            hi = t[idx].copy()
            for _ in range(8):
                mid = (lo + hi) / 2
                pm = CAM + dirs[idx] * mid[:, None]
                gm, _ = height_at(hf, pm[:, 0], pm[:, 2])
                under = pm[:, 1] <= gm
                hi = np.where(under, mid, hi)
                lo = np.where(under, lo, mid)
            t[idx] = hi
            hit[idx] = True
        alive = alive[~below & ~out]
        t[alive] += np.maximum(0.06, t[alive] * 0.006)
    t = np.where(hit, t, np.inf)
    p = CAM + dirs * np.where(hit, t, 0)[:, None]
    return p.reshape(h, w, 3), hit.reshape(h, w), t.reshape(h, w)


def sample_grid(grid, x, z):
    fx = np.clip(((x - X0) / DX).round().astype(int), 0, NX - 1)
    fz = np.clip(((z - Z0) / DZ).round().astype(int), 0, NZ - 1)
    return grid[fz, fx]


# ---------------------------------------------------------------------------
# Pixel props.

def rgba(c, a=255):
    c = hex_rgb(c) if isinstance(c, str) else c
    return tuple(int(v) for v in c[:3]) + (a,)


def prop_sprite(kind, rng):
    """One small pixel-art prop, lit from the upper left."""
    if kind == "tree":
        w, h = 32, 48
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        tall = rng.uniform(0.7, 1.15)  # crown spread; tall trees are narrow
        top = int(rng.uniform(4, 14))
        crown_y = top + 10
        d.rectangle([14, crown_y + 4, 17, h - 1], fill=rgba("#4a3020"))
        d.line([(14, crown_y + 4), (14, h - 1)], fill=rgba("#6a4830"))
        palettes = [
            ["#1e3f1a", "#2f5a24", "#467a30", "#6a9a3c"],
            ["#16352a", "#24503a", "#3a6e48", "#5a9058"],
            ["#2a4418", "#3e6222", "#5a8430", "#86aa44"],
        ]
        greens = palettes[int(rng.integers(0, len(palettes)))]
        spread = 7 * tall
        for k in range(30):
            cx = 16 + rng.normal(0, spread)
            cy = crown_y + rng.normal(0, 5)
            r = rng.uniform(3, 6)
            light = 1 if cx < 16 and cy < crown_y else 0
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba(greens[1 + light]))
        for k in range(14):
            cx = 13 + rng.normal(0, spread * 0.6)
            cy = crown_y - 4 + rng.normal(0, 3)
            d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=rgba(greens[3]))
        for k in range(16):
            cx = 19 + rng.normal(0, spread * 0.6)
            cy = crown_y + 5 + rng.normal(0, 3)
            d.ellipse([cx - 2, cy - 1, cx + 2, cy + 2], fill=rgba(greens[0]))
        for k in range(5):  # hanging moss
            x = int(rng.uniform(6, 26))
            d.line([(x, crown_y + 5), (x, crown_y + 5 + int(rng.uniform(3, 8)))], fill=rgba("#8aa058"))
        return im
    if kind == "fern":
        w, h = 14, 10
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for a in range(-3, 4):
            d.line([(7, h - 1), (7 + a * 2, 2 + abs(a))], fill=rgba("#4f8a30" if a < 0 else "#2f5a22"))
        return im
    if kind == "groundsel":
        w, h = 20, 34
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rectangle([8, 10, 11, h - 1], fill=rgba("#5a4a38"))
        d.line([(8, 10), (8, h - 1)], fill=rgba("#7a6a50"))
        for y in range(14, h - 2, 3):  # dead leaf skirt
            d.line([(7, y), (12, y + 1)], fill=rgba("#8a7a5a"))
        for cx, cy in ((5, 8), (14, 6), (10, 4)):
            d.ellipse([cx - 5, cy - 3, cx + 5, cy + 3], fill=rgba("#3e6a2a"))
            d.ellipse([cx - 3, cy - 3, cx + 2, cy + 1], fill=rgba("#6a9a40"))
            d.line([(cx, cy), (cx, cy + 4)], fill=rgba("#5a4a38"))
        return im
    if kind == "lobelia":
        w, h = 8, 20
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.ellipse([0, 2, 7, h - 1], fill=rgba("#4a6a3a"))
        for y in range(4, h - 2, 2):
            d.line([(1, y), (6, y)], fill=rgba("#6a8a52"))
        d.line([(2, 4), (2, h - 4)], fill=rgba("#8aa66a"))
        return im
    if kind == "heather":
        w, h = 10, 6
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.ellipse([0, 0, w - 1, h - 1], fill=rgba("#5e5a34"))
        d.ellipse([1, 0, 5, 3], fill=rgba("#7a6a4e"))
        return im
    if kind == "cairn":
        w, h = 10, 14
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for i, (y, r) in enumerate(((11, 4), (7, 3), (4, 2), (1, 1))):
            d.ellipse([5 - r, y - 2, 5 + r, y + 2], fill=rgba("#8a8078"))
            d.point((5 - r + 1, y - 1), fill=rgba("#c0b8ae"))
        return im
    if kind == "serac":
        w, h = 16, 26
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        pts = [(2, h - 1), (4, 6), (8, 1), (12, 5), (14, h - 1)]
        d.polygon(pts, fill=rgba("#a8cce4"))
        d.polygon([(4, 6), (8, 1), (8, h - 1), (2, h - 1)], fill=rgba("#e4f2fa"))
        d.line([(8, 3), (8, h - 2)], fill=rgba("#7aa8c8"))
        return im
    # boulder
    w, h = 18, 12
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 2, w - 1, h - 1], fill=rgba("#4a4440"))
    d.ellipse([1, 1, w - 5, h - 4], fill=rgba("#6e665e"))
    d.ellipse([3, 2, 8, 5], fill=rgba("#948a7e"))
    return im


PROP_HEIGHT = {  # world units tall
    "tree": 9.0,
    "fern": 1.2,
    "groundsel": 4.6,
    "lobelia": 1.8,
    "heather": 0.8,
    "cairn": 1.3,
    "serac": 4.0,
    "boulder": 1.6,
}


def place_props(zone, t, depth, w, h, rng):
    """Billboards: positions, then drawn far to near where they are seen."""
    items = []
    for kind, density, keep in zone["props"]:
        count = int(density * NX * NZ * 0.25)
        xs = rng.uniform(X0 + 4, X1 - 4, count)
        zs = rng.uniform(8, 200, count)
        d = np.abs(xs - trail_x(zs, zone))
        cx, cz = t["camp"]
        ok = (d > keep) & (np.hypot(xs - cx, zs - cz) > 8)
        if kind in ("groundsel", "lobelia"):
            ok &= d < zone["open"] + 22
        for x, z in zip(xs[ok], zs[ok]):
            y = float(height_at(t["h"], np.array([x]), np.array([z]))[0][0])
            slope_ok = True
            if kind != "serac":
                g1 = float(height_at(t["h"], np.array([x + 1]), np.array([z]))[0][0])
                g2 = float(height_at(t["h"], np.array([x]), np.array([z + 1]))[0][0])
                slope_ok = abs(g1 - y) < 1.0 and abs(g2 - y) < 1.0
            if not slope_ok and kind != "tree":
                continue
            items.append((kind, x, y, z))
    return items


def draw_props(img, items, depth, w, h, rng):
    cache = {}
    order = []
    for kind, x, y, z in items:
        sx, sy, zc = project(np.array([x, y, z]), w, h)
        if not (0 <= sx < w and 0 <= sy < h + 40) or zc <= 1 or zc > 170:
            continue
        # Keep the near ground open: tall things only at the edges up close.
        if kind in ("tree", "groundsel") and zc < 70 and abs(sx / w - 0.5) < 0.3:
            continue
        iy = int(min(h - 1, max(0, sy - 1)))
        ix = int(sx)
        seen = depth[iy, ix]
        if not (zc <= seen * 1.04 + 0.8):
            continue
        order.append((zc, kind, sx, sy))
    order.sort(key=lambda o: -o[0])
    focal = h / 2 / math.tan(VFOV / 2)
    for zc, kind, sx, sy in order:
        key = (kind, int(rng.integers(0, 8)))
        if key not in cache:
            spr = prop_sprite(kind, np.random.default_rng(hash(key) % 2**32))
            cache[key] = selective_outline(spr, darken=0.35) if kind not in ("heather", "fern") else spr
        spr = cache[key]
        px_h = PROP_HEIGHT[kind] * focal / zc * rng.uniform(0.75, 1.25)
        scale = max(0.5, px_h / spr.height)
        sw, sh = max(1, round(spr.width * scale)), max(1, round(spr.height * scale))
        s = spr.resize((sw, sh), Image.NEAREST)
        if rng.random() < 0.5:
            s = s.transpose(Image.FLIP_LEFT_RIGHT)
        # A soft contact shadow, then the sprite.
        shadow = Image.new("RGBA", (sw + 6, max(3, sh // 6)), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).ellipse([0, 0, sw + 5, max(2, sh // 6) - 1], fill=(10, 14, 10, 90))
        img.alpha_composite(shadow, (int(sx - sw / 2 + 2), int(sy - shadow.height / 2)))
        img.alpha_composite(s, (int(sx - sw / 2), int(sy - sh)))


# ---------------------------------------------------------------------------


def render(name, scale=1.0):
    zone = ZONES[name]
    w, h = int(W * scale), int(H * scale)
    t = terrain(zone)
    n = normals(t["h"])
    sh = shadows(t["h"])
    cav = cavity(t["h"])
    a = albedo(name, t, n)
    lambert = np.clip(n @ SUN, 0, 1)
    sky = np.clip(n[:, :, 1], 0, 1)
    warm = col("#fff0d8")
    cool = col("#8aa0c0") if name != "snow" else col("#a8c0e0")
    light = (lambert * (0.25 + 0.75 * sh))[..., None] * warm * 1.05 + (sky * 0.42)[..., None] * cool
    shade = a * light * (1 + cav)[..., None]
    shade = np.clip(shade, 0, 1)

    p, hit, depth = raycast(t["h"], w, h)
    rgb = sample_grid(shade, p[:, :, 0], p[:, :, 2])

    # Air between the camera and the far ground.
    haze = col("#c8d4dc") if name != "rainforest" else col("#b4c8b8")
    k = smoothstep(60, 260, np.where(hit, depth, 400))[..., None] * 0.75
    rgb = rgb * (1 - k) + haze * k

    alpha = hit.astype(float)
    img = Image.fromarray(np.dstack([np.clip(rgb * 255, 0, 255), alpha * 255]).astype(np.uint8), "RGBA")
    rng = np.random.default_rng(int(zone["seed"] * 77))
    draw_props(img, place_props(zone, t, depth, w, h, rng), np.where(hit, depth, np.inf), w, h, rng)

    # Where things go on the plate, in 0..1 of its width and height.
    zs = np.arange(10.0, 150.0, 1.0)
    xs = trail_x(zs, zone)
    ys, _ = height_at(t["h"], xs, zs)
    sx, sy, zc = project(np.stack([xs, ys, zs], axis=1), w, h)
    focal = h / 2 / math.tan(VFOV / 2)
    trail = [
        {"x": round(float(a_) / w, 4), "y": round(float(b_) / h, 4), "scale": round(float(focal / c_ / h), 5)}
        for a_, b_, c_ in zip(sx, sy, zc)
        if 0 <= b_ <= h
    ]
    cx, cz = t["camp"]
    cy = float(height_at(t["h"], np.array([cx]), np.array([cz]))[0][0])
    csx, csy, czc = project(np.array([cx, cy, cz]), w, h)
    meta = {
        "zone": name,
        "width": w,
        "height": h,
        "unitsPerPersonHeight": 1.8,
        "trail": trail,
        "camp": {"x": round(float(csx) / w, 4), "y": round(float(csy) / h, 4), "scale": round(float(focal / czc / h), 5)},
    }
    return img, meta


def fog_texture():
    rng = np.random.default_rng(91)
    n = fbm(512, 256, 4, 5, rng, wrap=True)
    a = np.clip((n - 0.38) * 2.2, 0, 1) ** 1.4
    rgb = np.full((256, 512, 3), 255, dtype=np.uint8)
    return Image.fromarray(np.dstack([rgb, (a * 255).astype(np.uint8)]), "RGBA")


def route_map():
    """The parchment route map: Kibo's cone from above, and its shoulders."""
    size = 256
    rng = np.random.default_rng(5)
    yy, xx = np.mgrid[0:size, 0:size] / size
    cx, cy = 0.56, 0.46
    r = np.hypot(xx - cx, yy - cy)
    cone = np.clip(1 - r / 0.62, 0, 1) ** 1.3
    shira = 0.35 * np.clip(1 - np.hypot(xx - 0.2, yy - 0.42) / 0.22, 0, 1)
    mawenzi = 0.5 * np.clip(1 - np.hypot(xx - 0.86, yy - 0.36) / 0.12, 0, 1)
    noise = fbm(size, size, 8, 4, rng, wrap=False)
    hgt = cone + shira + mawenzi + 0.08 * noise
    shade = np.clip(0.6 + (hgt - np.roll(np.roll(hgt, 2, 0), 2, 1)) * 8, 0, 1)
    paper = mix(col("#d8c49a"), col("#efe0bc"), noise)
    ink = mix(col("#6a5638"), col("#8a7450"), noise)
    rgb = paper * (0.75 + 0.3 * shade[..., None])
    snowcap = smoothstep(0.08, 0.05, r)
    rgb = mix(rgb, col("#f6f2ea"), snowcap * 0.9)
    contours = (np.abs(np.sin(hgt * 34)) < 0.08) & (hgt > 0.12)
    rgb = np.where(contours[..., None], mix(rgb, ink, 0.5), rgb)
    forest = smoothstep(0.62, 0.55, r) * smoothstep(0.5, 0.56, r) * (noise > 0.45)
    rgb = mix(rgb, col("#7a8a5a"), forest * 0.5)
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")


def camp_props():
    """Tents (two colours) and four campfire frames, on one strip."""
    im = Image.new("RGBA", (32 * 6, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, (lit, mid, dark) in enumerate((("#f2a640", "#d07a22", "#8a4a12"), ("#5a9ad0", "#3a70a8", "#1e4470"))):
        ox = i * 32
        d.polygon([(ox + 3, 22), (ox + 16, 5), (ox + 29, 22)], fill=rgba(mid))
        d.polygon([(ox + 3, 22), (ox + 16, 5), (ox + 14, 22)], fill=rgba(lit))
        d.polygon([(ox + 13, 22), (ox + 16, 12), (ox + 19, 22)], fill=rgba("#2a2018"))
        d.line([(ox + 16, 5), (ox + 29, 22)], fill=rgba(dark))
        d.line([(ox + 2, 23), (ox + 30, 23)], fill=rgba("#3a3028"))
        d.line([(ox + 16, 2), (ox + 16, 5)], fill=rgba("#c8c0b0"))
    for f in range(4):
        ox = 64 + f * 32
        for lx, ly in ((10, 21), (16, 22), (22, 21)):
            d.line([(ox + lx - 3, oy_(ly)), (ox + lx + 3, oy_(ly) - 1)], fill=rgba("#5a3a22"), width=2)
        flick = [(0, 0), (1, -1), (-1, 1), (1, 1)][f]
        d.polygon([(ox + 11, 21), (ox + 16 + flick[0], 8 + flick[1]), (ox + 21, 21)], fill=rgba("#e8682a"))
        d.polygon([(ox + 13, 21), (ox + 16 - flick[0], 12 - flick[1]), (ox + 19, 21)], fill=rgba("#f6b040"))
        d.polygon([(ox + 15, 21), (ox + 16, 16 + flick[1]), (ox + 17, 21)], fill=rgba("#fff0a0"))
    return selective_outline(im, cell=(32, 24), darken=0.35)


def oy_(y):
    return y


def main():
    WORLD.mkdir(parents=True, exist_ok=True)
    names = [sys.argv[1]] if len(sys.argv) > 1 and sys.argv[1] in ZONES else list(ZONES)
    scale = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
    for name in names:
        img, meta = render(name, scale)
        img.save(WORLD / f"{name}.webp", quality=88, method=6)
        (WORLD / f"{name}.json").write_text(json.dumps(meta, separators=(",", ":")))
        print(f"wrote {name}: {len(meta['trail'])} trail points")
    if len(names) > 1:
        fog_texture().save(WORLD / "fog.png")
        route_map().save(WORLD / "map.png")
        camp_props().save(WORLD / "props.png")
        print("wrote fog, map, props")


if __name__ == "__main__":
    main()
