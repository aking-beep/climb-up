"""
The expedition's camp screen, drawn smooth for phones: the zone plates,
the party walking and sitting at camp, the tents and the fire. Replaces
the pixel props and sprites of tools/art/diorama.py with illustrated ones
in the style of the climbers (tools/art/characters_hd.py): rounded shapes,
cel shading lit from the upper left, a soft dark outline, anti-aliased.

- Plates: the same ray-cast valley as diorama.py (same trail and camp,
  so the party stands where it did), rendered at twice the output size
  and scaled down (no jagged ridge lines), then dressed with smooth props:
  rainforest trees with layered canopies and hanging moss, giant
  groundsels and lobelias on the moorland, boulders and cairns, snow-capped
  stones on the summit. Air gets hazier and cooler with distance.
- People: 8 x 2 frames of 32 x 40 world px (the layout of the pixel map
  sprites: walking away 0-3, walking toward 4-7, idle 8-9, kneel 10, sit
  11), drawn at 4x: 128 x 160 px frames.
- Props: two tents and four fire frames, 32 x 24 world px each, at 4x.

Writes to godot/assets/world/: <zone>.webp and <zone>.json (the plates,
replacing the pixel ones), hd/<who>-map.png, hd/props.png.

    python3 tools/art/diorama_hd.py              # everything
    python3 tools/art/diorama_hd.py people       # just the sprites
    python3 tools/art/diorama_hd.py moorland     # one plate
"""

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import diorama as D
from characters import PARTY

ROOT = Path(__file__).resolve().parents[2]
WORLD = ROOT / "godot" / "assets" / "world"
OUT_W, OUT_H = 1280, 1024
SS = 2


def c(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(rgb, k, a=255):
    return tuple(int(max(0, min(255, v * k))) for v in rgb[:3]) + (a,)


# ---------------------------------------------------------------------------
# Smooth props, drawn into the (supersampled) plate at their place.


class Brush:
    """Draws a prop in its own units: 1.0 is the prop's height in pixels,
    x from its centre, y up from its foot."""

    def __init__(self, d, foot, size):
        self.d, self.fx, self.fy, self.s = d, foot[0], foot[1], size
        self.o = max(1.0, size * 0.035)  # outline, pixels

    def p(self, x, y):
        return (self.fx + x * self.s, self.fy - y * self.s)

    def ellipse(self, x, y, rx, ry, fill, outline=None):
        if outline:
            a, b = self.p(x - rx, y + ry), self.p(x + rx, y - ry)
            self.d.ellipse([a[0] - self.o, a[1] - self.o, b[0] + self.o, b[1] + self.o], fill=outline)
        a, b = self.p(x - rx, y + ry), self.p(x + rx, y - ry)
        self.d.ellipse([a[0], a[1], b[0], b[1]], fill=fill)

    def poly(self, pts, fill, outline=None):
        q = [self.p(x, y) for x, y in pts]
        if outline:
            self.d.line(q + q[:1], fill=outline, width=max(1, int(self.o * 2)), joint="curve")
        self.d.polygon(q, fill=fill)

    def line(self, pts, w, fill):
        self.d.line([self.p(x, y) for x, y in pts], fill=fill, width=max(1, int(w * self.s)), joint="curve")


def tree(b, rng, zone):
    greens = [("#1f4a2a", "#2f6b34", "#4d8f3e", "#8cc05a"), ("#1c4434", "#2a6046", "#428058", "#7fb47a"),
              ("#2c4a1c", "#406a24", "#5f8e30", "#a2c45a")][int(rng.integers(0, 3))]
    dark = c("#1a2a14")
    trunk = c("#5a3a24")
    # Trunk, slightly leaning.
    lean = rng.uniform(-0.04, 0.04)
    b.poly([(-0.05, 0), (0.05, 0), (0.03 + lean, 0.62), (-0.03 + lean, 0.62)], trunk, dark)
    b.line([(-0.02, 0.02), (-0.01 + lean, 0.55)], 0.012, c("#7a5236"))
    # The canopy: back blobs in shadow, then the mass, then lit tops.
    blobs = [(rng.uniform(-0.22, 0.22), rng.uniform(0.6, 0.92), rng.uniform(0.14, 0.22)) for _ in range(6)]
    blobs.sort(key=lambda t: -t[1])
    for x, y, r in blobs:
        b.ellipse(x + lean, y, r, r * 0.85, c(greens[1]), dark)
    for x, y, r in blobs:
        b.ellipse(x + lean + 0.02, y - 0.03, r * 0.8, r * 0.6, c(greens[0]))
    for x, y, r in blobs[-3:]:
        b.ellipse(x + lean - r * 0.25, y + r * 0.3, r * 0.55, r * 0.4, c(greens[2]))
        b.ellipse(x + lean - r * 0.35, y + r * 0.45, r * 0.25, r * 0.18, c(greens[3]))
    if zone == "rainforest":
        for _ in range(4):  # hanging moss
            x = rng.uniform(-0.2, 0.2)
            y = rng.uniform(0.58, 0.7)
            b.line([(x, y), (x + 0.01, y - rng.uniform(0.06, 0.14))], 0.012, c("#a8c070"))


def groundsel(b, rng, zone):
    dark = c("#2a2018")
    # A thick trunk in a shaggy skirt of dead leaves.
    b.poly([(-0.08, 0), (0.08, 0), (0.06, 0.55), (-0.06, 0.55)], c("#6a5638"), dark)
    for i in range(7):
        y = 0.08 + i * 0.065
        b.ellipse(0.0, y, 0.11 - i * 0.004, 0.045, c("#8a7650" if i % 2 else "#a08a60"))
    # Branches, each with a rosette of leaves.
    arms = [(-0.2, 0.82), (0.2, 0.78), (0.02, 0.98)][: int(rng.integers(2, 4))]
    for ax, ay in arms:
        b.line([(0, 0.55), (ax * 0.6, ay - 0.15), (ax, ay - 0.05)], 0.05, c("#6a5638"))
    for ax, ay in arms:
        pts = []
        for k in range(16):
            a = k / 16 * math.tau
            r = 0.15 if k % 2 == 0 else 0.07
            pts.append((ax + math.cos(a) * r, ay + math.sin(a) * r * 0.55))
        b.poly(pts, c("#3e7a34"), dark)
        b.ellipse(ax - 0.02, ay + 0.02, 0.07, 0.04, c("#7ab452"))
        b.ellipse(ax - 0.03, ay + 0.035, 0.03, 0.018, c("#b4dc7c"))


def lobelia(b, rng, zone):
    dark = c("#1e2c1c")
    b.ellipse(0, 0.45, 0.16, 0.45, c("#4a7046"), dark)
    for i in range(9):
        y = 0.08 + i * 0.09
        b.ellipse(-0.02, y, 0.13 - abs(i - 4) * 0.012, 0.035, c("#6e9a5e" if i % 2 else "#5a8450"))
    b.ellipse(-0.06, 0.62, 0.04, 0.2, c("#9ac48a", 160))


def heather(b, rng, zone):
    for k in range(3):
        x = (k - 1) * 0.35
        b.ellipse(x, 0.35, 0.4, 0.32, c("#5e6a36"), c("#2a3018"))
        b.ellipse(x - 0.1, 0.48, 0.2, 0.14, c("#8a8a4e"))
        b.ellipse(x + 0.05, 0.55, 0.06, 0.05, c("#b07aa8"))


def fern(b, rng, zone):
    for k in range(-3, 4):
        a = k * 0.32
        b.line([(0, 0), (math.sin(a) * 0.6, math.cos(a) * 0.9)], 0.08, c("#4e8a34" if k < 0 else "#36682a"))


def boulder(b, rng, zone):
    tone = {"snow": "#7a7e88", "desert": "#7e6e62", "moorland": "#6e6a62"}.get(zone, "#666660")
    base = c(tone)
    pts = []
    n = 9
    for k in range(n):
        a = math.pi * k / (n - 1)
        r = rng.uniform(0.85, 1.0)
        pts.append((math.cos(a) * 0.55 * r, math.sin(a) * 0.9 * r))
    b.ellipse(0.05, 0.02, 0.65, 0.12, c("#000000", 60))
    b.poly(pts, base, c("#24222a"))
    b.poly([(x * 0.7 - 0.12, y * 0.7 + 0.12) for x, y in pts[3:]], shade(base, 1.25))
    b.poly([(x * 0.6 + 0.18, y * 0.5) for x, y in pts[:4]], shade(base, 0.75))
    if zone == "snow":
        b.poly([(x * 0.85, y * 0.4 + 0.55) for x, y in pts[2:7]], c("#f4f8fc"))


def cairn(b, rng, zone):
    for i, (y, r) in enumerate(((0.12, 0.32), (0.38, 0.26), (0.6, 0.2), (0.8, 0.14), (0.95, 0.08))):
        b.ellipse(0, y, r, 0.11, c("#8a8078"), c("#2a2620"))
        b.ellipse(-r * 0.3, y + 0.04, r * 0.4, 0.04, c("#bab0a4"))


PROPS = {"tree": tree, "groundsel": groundsel, "lobelia": lobelia, "heather": heather, "fern": fern,
         "boulder": boulder, "cairn": cairn, "serac": boulder}


def draw_props_hd(img, items, depth, w, h, rng, zone_name):
    """Far to near, each at its depth, as diorama.draw_props, but drawn."""
    d = ImageDraw.Draw(img)
    order = []
    for kind, x, y, z in items:
        sx, sy, zc = D.project(np.array([x, y, z]), w, h)
        if not (0 <= sx < w and 0 <= sy < h + 40) or zc <= 1 or zc > 170:
            continue
        if kind in ("tree", "groundsel") and zc < 70 and abs(sx / w - 0.5) < 0.3:
            continue
        iy = int(min(h - 1, max(0, sy - 1)))
        if not (zc <= depth[iy, int(sx)] * 1.04 + 0.8):
            continue
        order.append((zc, kind, sx, sy))
    order.sort(key=lambda o: -o[0])
    focal = h / 2 / math.tan(D.VFOV / 2)
    haze = c("#c8d4dc") if zone_name != "rainforest" else c("#b4c8b8")
    for zc, kind, sx, sy in order:
        px_h = D.PROP_HEIGHT[kind] * focal / zc * rng.uniform(0.8, 1.2)
        if px_h < 3:
            continue
        # Each prop is drawn on its own layer, then hazed with distance.
        pad = int(px_h * 1.6) + 4
        layer = Image.new("RGBA", (pad * 2, pad * 2), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        wide = 1.0 if kind not in ("boulder", "heather", "fern", "serac") else 0.6
        PROPS[kind](Brush(ld, (pad, pad * 1.5), px_h * wide if kind in ("boulder", "heather", "fern", "serac") else px_h), rng, zone_name)
        if rng.random() < 0.5:
            layer = layer.transpose(Image.FLIP_LEFT_RIGHT)
        k = float(D.smoothstep(60, 260, zc)) * 0.75
        if k > 0.01:
            tint = Image.new("RGBA", layer.size, haze)
            mask = layer.split()[3].point(lambda v: int(v * k))
            layer.paste(tint, (0, 0), mask)
        shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sw = px_h * (0.35 if kind in ("tree", "groundsel", "lobelia") else 0.5)
        sd.ellipse([pad - sw, pad * 1.5 - px_h * 0.06, pad + sw * 1.3, pad * 1.5 + px_h * 0.06], fill=(12, 16, 14, 80))
        img.alpha_composite(shadow, (int(sx - pad), int(sy - pad * 1.5)))
        img.alpha_composite(layer, (int(sx - pad), int(sy - pad * 1.5)))


def sample_bilinear(grid, x, z):
    """Terrain colour between the grid's cells (diorama.sample_grid takes
    the nearest, which shows the grid as blocks up close)."""
    fx = np.clip((x - D.X0) / D.DX, 0, D.NX - 1.001)
    fz = np.clip((z - D.Z0) / D.DZ, 0, D.NZ - 1.001)
    x0 = fx.astype(int)
    z0 = fz.astype(int)
    tx = (fx - x0)[..., None]
    tz = (fz - z0)[..., None]
    a, b = grid[z0, x0], grid[z0, x0 + 1]
    c_, d = grid[z0 + 1, x0], grid[z0 + 1, x0 + 1]
    return (a * (1 - tx) + b * tx) * (1 - tz) + (c_ * (1 - tx) + d * tx) * tz


def raycast_fine(hf, w, h, step=0.0032):
    """diorama.raycast with a finer march, so thin ridge tops against the
    sky are not stepped over (no stair-stepped skyline)."""
    dirs = D.rays(w, h).reshape(-1, 3)
    n = dirs.shape[0]
    t = np.full(n, 4.0)
    hit = np.zeros(n, dtype=bool)
    alive = np.arange(n)
    for _ in range(2600):
        if alive.size == 0:
            break
        dd = dirs[alive]
        tt = t[alive]
        p = D.CAM + dd * tt[:, None]
        g, inside = D.height_at(hf, p[:, 0], p[:, 2])
        below = inside & (p[:, 1] <= g)
        out = (~inside & (tt > 30)) | (tt > 420)
        if below.any():
            idx = alive[below]
            lo = t[idx] - np.maximum(0.04, t[idx] * step)
            hi = t[idx].copy()
            for _ in range(10):
                mid = (lo + hi) / 2
                pm = D.CAM + dirs[idx] * mid[:, None]
                gm, _ = D.height_at(hf, pm[:, 0], pm[:, 2])
                under = pm[:, 1] <= gm
                hi = np.where(under, mid, hi)
                lo = np.where(under, lo, mid)
            t[idx] = hi
            hit[idx] = True
        alive = alive[~below & ~out]
        t[alive] += np.maximum(0.04, t[alive] * step)
    t = np.where(hit, t, np.inf)
    p = D.CAM + dirs * np.where(hit, t, 0)[:, None]
    return p.reshape(h, w, 3), hit.reshape(h, w), t.reshape(h, w)


def render_plate(name):
    zone = D.ZONES[name]
    w, h = OUT_W * SS, OUT_H * SS
    scale = w / D.W
    t = D.terrain(zone)
    n = D.normals(t["h"])
    # Cast shadows are computed per grid cell: soften their edges, or steep
    # walls show the grid as a staircase.
    sh = np.clip(D.box_blur(D.shadows(t["h"]).astype(float), 2), 0, 1)
    cav = D.cavity(t["h"])
    a = D.albedo(name, t, n)
    lambert = np.clip(n @ D.SUN, 0, 1)
    sky = np.clip(n[:, :, 1], 0, 1)
    warm = D.col("#fff0d8")
    cool = D.col("#8aa0c0") if name != "snow" else D.col("#a8c0e0")
    light = (lambert * (0.25 + 0.75 * sh))[..., None] * warm * 1.05 + (sky * 0.42)[..., None] * cool
    shaded = np.clip(a * light * (1 + cav)[..., None], 0, 1)
    p, hit, depth = raycast_fine(t["h"], w, h)
    rgb = sample_bilinear(shaded, p[:, :, 0], p[:, :, 2])
    haze = D.col("#c8d4dc") if name != "rainforest" else D.col("#b4c8b8")
    k = D.smoothstep(60, 260, np.where(hit, depth, 400))[..., None] * 0.75
    rgb = rgb * (1 - k) + haze * k
    alpha = hit.astype(float)
    img = Image.fromarray(np.dstack([np.clip(rgb * 255, 0, 255), alpha * 255]).astype(np.uint8), "RGBA")
    # A painted finish: the per-pixel grain of the height field smoothed
    # into strokes, without softening the silhouette.
    rgb_im = img.convert("RGB").filter(ImageFilter.ModeFilter(5)).filter(ImageFilter.SMOOTH_MORE)
    img = Image.merge("RGBA", (*rgb_im.split(), img.split()[3]))
    rng = np.random.default_rng(int(zone["seed"] * 77))
    draw_props_hd(img, D.place_props(zone, t, depth, w, h, rng), np.where(hit, depth, np.inf), w, h, rng, name)
    img = img.resize((OUT_W, OUT_H), Image.LANCZOS)
    # Where things go, in 0..1 of the plate (the same as diorama.py's).
    zs = np.arange(10.0, 150.0, 1.0)
    xs = D.trail_x(zs, zone)
    ys, _ = D.height_at(t["h"], xs, zs)
    sx, sy, zc = D.project(np.stack([xs, ys, zs], axis=1), w, h)
    focal = h / 2 / math.tan(D.VFOV / 2)
    trail = [{"x": round(float(a_) / w, 4), "y": round(float(b_) / h, 4), "scale": round(float(focal / c_ / h), 5)}
             for a_, b_, c_ in zip(sx, sy, zc) if 0 <= b_ <= h]
    cx, cz = t["camp"]
    cy = float(D.height_at(t["h"], np.array([cx]), np.array([cz]))[0][0])
    csx, csy, czc = D.project(np.array([cx, cy, cz]), w, h)
    meta = {"zone": name, "width": OUT_W, "height": OUT_H, "unitsPerPersonHeight": 1.8, "trail": trail,
            "camp": {"x": round(float(csx) / w, 4), "y": round(float(csy) / h, 4), "scale": round(float(focal / czc / h), 5)}}
    return img, meta


# ---------------------------------------------------------------------------
# The party on the map: 32 x 40 frames at 4x.

S = 4          # texels per world px
K = S * 2      # drawn at 2x, scaled down
FW, FH = 32, 40
LINE = (34, 24, 30, 255)
SKIN = ("#f9d9b0", "#e9b688")
PANTS = ("#5e5246", "#41382f")
BOOT = ("#8a5a32", "#5a3a1e")
PACK = ("#c09a5c", "#8a6a38", "#5e4626")
MAT = ("#69b3cc", "#3f8199")


class P:
    def __init__(self, d, ox, oy):
        self.d, self.ox, self.oy = d, ox, oy
        self.o = 0.7

    def q(self, x, y):
        return ((self.ox + x) * K, (self.oy + y) * K)

    def ell(self, x0, y0, x1, y1, fill, line=True):
        if line:
            self.d.ellipse([*self.q(x0 - self.o, y0 - self.o), *self.q(x1 + self.o, y1 + self.o)], fill=LINE)
        self.d.ellipse([*self.q(x0, y0), *self.q(x1, y1)], fill=fill)

    def rr(self, x0, y0, x1, y1, r, fill, line=True):
        if line:
            self.d.rounded_rectangle([*self.q(x0 - self.o, y0 - self.o), *self.q(x1 + self.o, y1 + self.o)], radius=(r + self.o) * K, fill=LINE)
        self.d.rounded_rectangle([*self.q(x0, y0), *self.q(x1, y1)], radius=r * K, fill=fill)

    def cap(self, pts, w, fill, line=True):
        q = [self.q(x, y) for x, y in pts]
        if line:
            self.d.line(q, fill=LINE, width=int((w + 2 * self.o) * K), joint="curve")
            for x, y in (pts[0], pts[-1]):
                self.dot(x, y, w / 2 + self.o, LINE)
        self.d.line(q, fill=fill, width=int(w * K), joint="curve")
        for x, y in pts:
            self.dot(x, y, w / 2, fill)

    def dot(self, x, y, r, fill):
        cx, cy = self.q(x, y)
        self.d.ellipse([cx - r * K, cy - r * K, cx + r * K, cy + r * K], fill=fill)


def person(p, who, view, step=0, pose="walk", bob=0.0):
    """view: back (walking away), front (toward). pose: walk, idle, kneel, sit."""
    jl, jm, jd = [c(x) for x in who["jacket"]]
    hl, hm, hd = [c(x) for x in who["hat"]]
    hair = c(who["hair"][0])
    cx = 16
    ground = 38.5
    swing = [0, 1, 0, -1][step % 4] if pose == "walk" else 0
    lift = [0, 0.6, 0, 0.6][step % 4] if pose == "walk" else 0
    y0 = bob - lift * 0.4
    if pose == "sit":
        # Cross-legged on a mat, seen from the front.
        p.rr(cx - 7, ground - 3.2, cx + 7, ground - 0.4, 1.4, c(MAT[0]))
        p.ell(cx - 7.5, ground - 5, cx + 0.5, ground - 1.5, c(PANTS[0]))
        p.ell(cx - 0.5, ground - 5, cx + 7.5, ground - 1.5, c(PANTS[1]))
        body_top, body_bot = ground - 16 + bob, ground - 3.5
    elif pose == "kneel":
        p.ell(cx - 5, ground - 4.5, cx + 1, ground - 0.5, c(PANTS[1]))
        p.rr(cx + 0.5, ground - 9, cx + 4, ground - 0.5, 1.5, c(PANTS[0]))
        p.rr(cx + 0.5, ground - 2.6, cx + 5.5, ground, 1.0, c(BOOT[0]))
        body_top, body_bot = ground - 19, ground - 5
    else:
        # Legs and boots, stepping.
        for side, k in ((-1, swing), (1, -swing)):
            lx = cx + side * 2.2
            ly = ground - 1.2 - (lift if k > 0 else 0)
            p.cap([(lx, ground - 10 + y0), (lx + k * 0.6, ly - 1)], 3.0, c(PANTS[0] if side < 0 else PANTS[1]))
            p.rr(lx - 1.9 + k * 0.6, ly - 2.0, lx + 1.9 + k * 0.6, ly + 0.8, 1.0, c(BOOT[0] if view == "front" else BOOT[1]))
        body_top, body_bot = ground - 22 + y0, ground - 9 + y0
    # Arms behind or beside the body.
    arm_swing = -swing * 1.6
    for side in (-1, 1):
        ax = cx + side * 5.6
        hand = (ax + side * 0.6, body_top + 11 + (arm_swing * side if pose == "walk" else 0))
        if pose == "kneel" and side > 0:
            hand = (cx + 3.5, ground - 8)
        if pose == "sit":
            hand = (cx + side * 4, ground - 5)
        p.cap([(ax, body_top + 3.5), hand], 2.6, jm if side < 0 else jd)
        p.dot(hand[0], hand[1], 1.3, c("#7e5432"))
    # The body: a rounded jacket.
    p.rr(cx - 5.5, body_top + 2, cx + 5.5, body_bot, 3.4, jm)
    p.rr(cx - 4.6, body_top + 2.8, cx - 0.6, body_bot - 1.5, 2.2, jl, line=False)
    if view == "front":
        p.cap([(cx, body_top + 4), (cx, body_bot - 1)], 0.5, c(who["trim"]), line=False)
    # Head, then the pack over the back (walking away), or the face (toward).
    hy = body_top - 6
    if view == "back" and pose == "walk":
        p.ell(cx - 5.5, hy, cx + 5.5, hy + 9.5, hair)
        p.ell(cx - 4.5, hy + 0.8, cx - 0.5, hy + 4, c(who["hair"][1]), line=False)
        # A big pack with a sleeping mat on top: the read from behind.
        p.rr(cx - 5.2, body_top + 3, cx + 5.2, body_bot + 0.5, 2.6, c(PACK[1]))
        p.rr(cx - 4.4, body_top + 3.6, cx + 0.2, body_bot - 1, 2.0, c(PACK[0]), line=False)
        p.rr(cx - 3.2, body_bot - 4.5, cx + 3.2, body_bot - 1.6, 1.0, c(PACK[2]), line=False)
        p.rr(cx - 6.5, body_top + 0.6, cx + 6.5, body_top + 3.6, 1.5, c(MAT[0]))
        p.rr(cx - 6.0, body_top + 1.0, cx + 6.0, body_top + 2.0, 0.8, c(MAT[1]), line=False)
    else:
        p.ell(cx - 5.5, hy, cx + 5.5, hy + 9.5, c(SKIN[0]))
        p.ell(cx + 0.5, hy + 4, cx + 5.3, hy + 9.2, c(SKIN[1]), line=False)
        p.ell(cx - 5.4, hy + 0.5, cx + 5.4, hy + 3.6, hair, line=False)
        for ex in (-2.0, 2.0):
            p.ell(cx + ex - 0.75, hy + 4.6, cx + ex + 0.75, hy + 6.4, c("#2a1e1a"), line=False)
            p.dot(cx + ex - 0.3, hy + 4.9, 0.3, c("#ffffff"))
        p.ell(cx - 4.2, hy + 6.2, cx - 2.6, hy + 7.2, c("#f2a090", 150), line=False)
        p.ell(cx + 2.6, hy + 6.2, cx + 4.2, hy + 7.2, c("#f2a090", 150), line=False)
        if pose == "kneel":
            # Head down, tired: a sweat drop.
            p.ell(cx + 5.5, hy + 1, cx + 7, hy + 3.2, c("#9ad4f0"), line=False)
    # Hat: a beanie with a bobble, or a sun hat.
    p.ell(cx - 5.8, hy - 1.5, cx + 5.8, hy + 4.2, hm)
    p.ell(cx - 4.8, hy - 1.0, cx - 0.2, hy + 2.0, hl, line=False)
    p.rr(cx - 6.0, hy + 2.6, cx + 6.0, hy + 4.4, 0.9, hd)
    p.ell(cx - 1.6, hy - 3.6, cx + 1.6, hy - 0.6, hl)


def people_sheets():
    out = WORLD / "hd"
    out.mkdir(parents=True, exist_ok=True)
    for name, who in PARTY.items():
        big = Image.new("RGBA", (FW * 8 * K, FH * 2 * K), (0, 0, 0, 0))
        d = ImageDraw.Draw(big)
        frames = [("back", i, "walk", 0) for i in range(4)] + [("front", i, "walk", 0) for i in range(4)] + \
                 [("front", 0, "idle", 0), ("front", 0, "idle", 0.5), ("front", 0, "kneel", 0), ("front", 0, "sit", 0)]
        for i, (view, step, pose, bob) in enumerate(frames):
            person(P(d, (i % 8) * FW, (i // 8) * FH), who, view, step, pose if pose != "idle" else "walk", bob)
        big.resize((FW * 8 * S, FH * 2 * S), Image.LANCZOS).save(out / f"{name}-map.png")
        print("wrote", out / f"{name}-map.png")


def camp_props_hd():
    big = Image.new("RGBA", (32 * 6 * K, 24 * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    for i, (lit, mid, dark) in enumerate((("#ffb84e", "#e88a2a", "#a85a14"), ("#6ab0e6", "#3f80c0", "#24508a"))):
        p = P(d, i * 32, 0)
        # Ground sheet, the fly, the shaded side, the door, guy lines.
        p.ell(2, 19.5, 30, 23.5, c("#000000", 70), line=False)
        d.polygon([p.q(3, 22), p.q(16, 4), p.q(29, 22)], fill=LINE)
        d.polygon([p.q(4, 21.4), p.q(16, 5.5), p.q(28, 21.4)], fill=c(mid))
        d.polygon([p.q(4, 21.4), p.q(16, 5.5), p.q(14.5, 21.4)], fill=c(lit))
        d.polygon([p.q(12.6, 21.4), p.q(16, 11.5), p.q(19.4, 21.4)], fill=c("#2a2018"))
        d.polygon([p.q(16, 5.5), p.q(28, 21.4), p.q(25, 21.4)], fill=c(dark))
        d.line([p.q(16, 2.5), p.q(16, 5.5)], fill=c("#d8d0c0"), width=int(0.8 * K))
        d.line([p.q(4, 21.4), p.q(0.5, 23.5)], fill=c("#e8e0d0", 180), width=int(0.3 * K))
        d.line([p.q(28, 21.4), p.q(31.5, 23.5)], fill=c("#e8e0d0", 180), width=int(0.3 * K))
    for f in range(4):
        p = P(d, 64 + f * 32, 0)
        p.ell(6, 19.5, 26, 23.5, c("#000000", 60), line=False)
        for a, b in (((9, 22), (23, 19.5)), ((9, 19.5), (23, 22))):
            p.cap([a, b], 2.0, c("#6a4226"))
        for sx in (7.5, 12, 20, 24.5):
            p.ell(sx - 1.6, 20.5, sx + 1.6, 23, c("#7e7870"))
        fl = [(0, 0), (0.8, -0.8), (-0.8, 0.6), (0.6, 0.8)][f]
        d.polygon([p.q(10.5, 21), p.q(13 + fl[0], 12), p.q(16 + fl[0], 6 + fl[1]), p.q(19, 12 - fl[1]), p.q(21.5, 21)], fill=c("#e8582a"))
        d.polygon([p.q(12.5, 21), p.q(16 - fl[0], 10 - fl[1]), p.q(19.5, 21)], fill=c("#f6a63a"))
        d.polygon([p.q(14.5, 21), p.q(16 + fl[1], 15 + fl[0]), p.q(17.5, 21)], fill=c("#fff2b0"))
    big.resize((32 * 6 * S, 24 * S), Image.LANCZOS).save(WORLD / "hd" / "props.png")
    print("wrote", WORLD / "hd" / "props.png")


def main():
    args = sys.argv[1:]
    if not args or "people" in args:
        people_sheets()
        camp_props_hd()
    zones = [a for a in args if a in D.ZONES] or ([] if args else list(D.ZONES))
    for name in zones:
        img, meta = render_plate(name)
        img.save(WORLD / f"{name}.webp", quality=82, method=6)
        (WORLD / f"{name}.json").write_text(json.dumps(meta, separators=(",", ":")))
        print(f"wrote {name}.webp {img.size}")


if __name__ == "__main__":
    main()
