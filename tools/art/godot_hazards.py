"""
Pixel art for the climbs' hazards and finds, in the style of the Godot tiles
(one texel per world pixel, dark outlines):

  godot/assets/terrain/hazards.png     16 x 16 tiles. Row 0: ice (4 variants).
                                       Row 1: cracked slabs (0-1 whole,
                                       2-3 breaking).
  godot/assets/terrain/props/rock.png        a falling rock, 10 x 10
  godot/assets/terrain/props/water.png       a water cache, 12 x 14
  godot/assets/terrain/props/gear.png        lost gear, 3 x (14 x 14):
                                             compass, ice axe, photograph

    python3 tools/art/godot_hazards.py
"""

import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
TERRAIN = ROOT / "godot" / "assets" / "terrain"
T = 16


def rgb(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


OUTLINE = rgb("#1c1714")


def ice(seed):
    rnd = random.Random(seed)
    im = Image.new("RGBA", (T, T))
    px = im.load()
    base, mid, light, deep = rgb("#9fc4dc"), rgb("#7fa7c4"), rgb("#e4f2fb"), rgb("#56789a")
    for y in range(T):
        for x in range(T):
            c = mid if (x + y + seed) % 7 < 3 else base
            if y > 10:
                c = deep if (x * 3 + y) % 5 == 0 else mid
            px[x, y] = c
    # A bright glazed top and a highlight streak, so ice reads at a glance.
    for x in range(T):
        px[x, 0] = light
        px[x, 1] = light if x % 3 else base
    for k in range(5):
        x, y = rnd.randrange(2, 12) + k, 3 + k
        if x < T and y < T:
            px[x, y] = light
    for _ in range(4):
        px[rnd.randrange(T), rnd.randrange(4, T)] = rgb("#ffffff", 220)
    return im


def crumble(seed, breaking):
    rnd = random.Random(seed)
    im = Image.new("RGBA", (T, T))
    px = im.load()
    a, b, top = rgb("#a8977c"), rgb("#938268"), rgb("#e2cfa4")
    for y in range(T):
        for x in range(T):
            px[x, y] = a if (x // 4 + y // 4 + seed) % 2 else b
    for x in range(T):
        px[x, 0] = top
        px[x, 1] = top if x % 2 else a
    # Cracks: dark, and wider when the slab is going.
    crack = OUTLINE
    x = rnd.randrange(4, 12)
    for y in range(1, T):
        px[x % T, y] = crack
        if breaking:
            px[(x + 1) % T, y] = crack
        x += rnd.choice([-1, 0, 1])
    # A seam down each side, so each slab reads as a separate stone.
    for y in range(T):
        px[0, y] = crack
    for _ in range(4 if not breaking else 8):
        cx, cy = rnd.randrange(T), rnd.randrange(2, T)
        for k in range(rnd.randint(2, 4)):
            px[(cx + k) % T, cy] = crack
    if breaking:
        for _ in range(6):
            px[rnd.randrange(T), rnd.randrange(T)] = (0, 0, 0, 0)
    return im


def outline(im):
    out = im.copy()
    src, px = im.load(), out.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                        px[x, y] = OUTLINE
                        break
    return out


def rock():
    im = Image.new("RGBA", (10, 10))
    px = im.load()
    for y in range(10):
        for x in range(10):
            d = ((x - 4.5) ** 2 + (y - 5) ** 2) ** 0.5
            if d < 4.2:
                px[x, y] = rgb("#8a7866") if x + y < 9 else rgb("#5f5144")
    px[3, 3] = rgb("#b5a38c")
    px[4, 3] = rgb("#b5a38c")
    return outline(im)


def water():
    im = Image.new("RGBA", (12, 14))
    px = im.load()
    # A blue water bag with a white cap, on a little stone.
    for y in range(4, 12):
        for x in range(2, 10):
            if not ((y == 4 or y == 11) and x in (2, 9)):
                px[x, y] = rgb("#3f7fb8") if x > 3 else rgb("#6aa6d6")
    for x in range(4, 8):
        px[x, 2] = rgb("#f2efe6")
        px[x, 3] = rgb("#d8d3c4")
    for x in range(1, 11):
        px[x, 12] = rgb("#7a6a5a")
        px[x, 13] = rgb("#5f5144")
    px[5, 7] = rgb("#ffffff")
    px[5, 8] = rgb("#cfe6f7")
    return outline(im)


def gear():
    sheet = Image.new("RGBA", (42, 14))
    # Compass: a brass disc with a red needle.
    c = Image.new("RGBA", (14, 14))
    p = c.load()
    for y in range(14):
        for x in range(14):
            d = ((x - 6.5) ** 2 + (y - 7) ** 2) ** 0.5
            if d < 5.5:
                p[x, y] = rgb("#c99a3c") if d > 4.2 else rgb("#efe6c8")
    for k in range(4):
        p[6, 3 + k] = rgb("#c0392b")
        p[7, 7 + k] = rgb("#2c3e50")
    sheet.paste(outline(c), (0, 0))
    # An old wooden ice axe.
    a = Image.new("RGBA", (14, 14))
    p = a.load()
    for k in range(10):
        p[3 + k // 2 + (k % 2), 3 + k] = rgb("#8b5a2b")
    for x in range(1, 10):
        p[x, 2] = rgb("#b8c0c8")
    p[1, 3] = rgb("#b8c0c8")
    p[9, 3] = rgb("#8a939c")
    sheet.paste(outline(a), (14, 0))
    # A photograph, curling at the corner.
    f = Image.new("RGBA", (14, 14))
    p = f.load()
    for y in range(3, 12):
        for x in range(2, 12):
            p[x, y] = rgb("#f4f1e8")
    for y in range(4, 9):
        for x in range(3, 11):
            p[x, y] = rgb("#7fa0b8") if y < 6 else rgb("#6b7f5a")
    for x in range(5, 9):
        p[x, 5 - abs(x - 7) // 2] = rgb("#e8eef2")
    p[11, 11] = (0, 0, 0, 0)
    sheet.paste(outline(f), (28, 0))
    return sheet


def everlasting():
    """Helichrysum, the papery everlasting of Kilimanjaro's moorland: a white
    star with a yellow eye on a short grey stem. Two frames: still, and
    catching the light."""
    sheet = Image.new("RGBA", (20, 10))
    for f in range(2):
        im = Image.new("RGBA", (10, 10))
        p = im.load()
        for y in range(6, 10):
            p[5, y] = rgb("#7d8a72")
        p[4, 8] = rgb("#7d8a72")
        petal = rgb("#f6f2e6") if f == 0 else rgb("#ffffff")
        for dx, dy in ((0, -2), (0, 2), (-2, 0), (2, 0), (-1, -1), (1, -1), (-1, 1), (1, 1)):
            p[5 + dx, 4 + dy] = petal
        p[5, 4] = rgb("#e8b730")
        if f == 1:
            p[7, 1] = rgb("#ffffff", 200)
        sheet.paste(outline(im), (f * 10, 0))
    return sheet


def main():
    atlas = Image.new("RGBA", (4 * T, 2 * T))
    for v in range(4):
        atlas.paste(ice(10 + v), (v * T, 0))
        atlas.paste(crumble(20 + v, breaking=v >= 2), (v * T, T))
    atlas.save(TERRAIN / "hazards.png")
    props = TERRAIN / "props"
    rock().save(props / "rock.png")
    water().save(props / "water.png")
    gear().save(props / "gear.png")
    everlasting().save(props / "everlasting.png")
    print("wrote", TERRAIN / "hazards.png", "and rock, water, gear props")


if __name__ == "__main__":
    main()
