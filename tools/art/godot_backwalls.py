"""
Crisp pixel-art rock for the inside of the mountain in the Godot climbs: the
back wall you see behind ledges, and deep rock you look straight into. One
texel per world pixel (16 per tile), tileable on both axes, in three
palettes: Barranco basalt, Lava Tower red, and summit night blue-grey.

These replace the painted cliff for these two layers: the painting is soft
next to the pixel tiles and the climber, which made the climbs look blurry.

    python3 tools/art/godot_backwalls.py
"""

import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "assets" / "scenery"
N = 256

PALETTES = {
    "barranco": {
        "bands": ["#4b4038", "#433931", "#53473d", "#3e352e", "#4f443a"],
        "light": "#62554a", "dark": "#2b241f", "fleck": "#6f6152", "snow": None,
    },
    "lava": {
        "bands": ["#5e372b", "#532f25", "#683f30", "#4b2a21", "#603a2c"],
        "light": "#7a4a38", "dark": "#2f1a14", "fleck": "#8a5641", "snow": None,
    },
    "summit": {
        "bands": ["#3f4556", "#383d4d", "#474e61", "#33384a", "#434a5c"],
        "light": "#58617a", "dark": "#22262f", "fleck": "#69738d", "snow": "#c9d3e6",
    },
}


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def scale(c, k):
    return tuple(max(0, min(255, round(v * k))) for v in c)


def wall(pal, seed, deep=False):
    rnd = random.Random(seed)
    bands = [hex_rgb(c) for c in pal["bands"]]
    light, dark, fleck = hex_rgb(pal["light"]), hex_rgb(pal["dark"]), hex_rgb(pal["fleck"])
    img = Image.new("RGB", (N, N))
    px = img.load()
    # Strata: band edges wander with whole-period waves, so the texture tiles.
    waves = [(rnd.choice([1, 2]), rnd.uniform(0, math.tau), rnd.uniform(0.6, 1.8)) for _ in range(2)]
    thick = [rnd.choice([14, 18, 22, 28, 32]) for _ in range(64)]
    edges = []
    y = 0
    while y < N:
        edges.append(y)
        y += thick[len(edges) % len(thick)]
    period = N

    def band_at(x, yy):
        off = sum(a * math.sin(f * math.tau * x / N + p) for f, p, a in waves)
        v = (yy + off) % period
        for i in range(len(edges) - 1, -1, -1):
            if v >= edges[i]:
                return i, v - edges[i]
        return 0, v

    for yy in range(N):
        for x in range(N):
            b, inside = band_at(x, yy)
            c = bands[b % len(bands)]
            if inside < 1:
                c = light  # the top lip of each stratum catches light
            elif inside < 2 and (x + yy) % 2 == 0:
                c = scale(light, 0.92)
            else:
                span = (edges[b + 1] if b + 1 < len(edges) else period) - edges[b]
                if inside >= span - 1:
                    c = dark  # and its underside is in shadow
                elif inside >= span - 2 and (x + yy) % 2 == 0:
                    c = scale(dark, 1.15)
            px[x, yy] = c
    # Joints: short vertical cracks inside the strata.
    for _ in range(90):
        x = rnd.randrange(N)
        y0 = rnd.randrange(N)
        for k in range(rnd.randint(3, 9)):
            px[x % N, (y0 + k) % N] = dark
            if rnd.random() < 0.25:
                x += rnd.choice([-1, 1])
    # Flecks of lighter rock, and frost on the summit.
    for _ in range(260):
        x, y = rnd.randrange(N), rnd.randrange(N)
        px[x, y] = fleck
    if pal["snow"]:
        snow = hex_rgb(pal["snow"])
        for _ in range(140):
            x, y = rnd.randrange(N), rnd.randrange(N)
            px[x, y] = snow
    if deep:
        img = img.point(lambda v: round(v * 0.62))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for seed, (name, pal) in enumerate(PALETTES.items()):
        wall(pal, 101 + seed).save(OUT / f"{name}-wall.png")
        wall(pal, 101 + seed, deep=True).save(OUT / f"{name}-wall-deep.png")
        print("wrote", OUT / f"{name}-wall.png", "and -deep")


if __name__ == "__main__":
    main()
