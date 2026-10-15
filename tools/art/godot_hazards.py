"""
Pixel art for the climbs' hazards and finds, in the style of the Godot tiles
(one texel per world pixel, dark outlines):

  godot/assets/terrain/hazards.png     16 x 16 tiles. Row 0: ice (4 variants).
                                       Row 1: cracked slabs (0-1 whole,
                                       2-3 breaking).
  godot/assets/terrain/props/rock.png        a falling rock, 10 x 10
  godot/assets/terrain/props/water.png       a water cache, 12 x 14
  godot/assets/terrain/props/gear.png        gear to find, 7 x (14 x 14):
                                             poles, gloves, goggles and buff,
                                             crampons, headlamp, helmet, rope

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
    """Five pieces of gear, each 14 x 14, in GEAR_KINDS order (climb_level.gd):
    trekking poles, gloves, goggles and buff, crampons, headlamp."""
    sheet = Image.new("RGBA", (98, 14))
    steel, dark, red, blue = rgb("#b8c0c8"), rgb("#6b737c"), rgb("#c0392b"), rgb("#2f6db0")
    # Trekking poles: two crossed shafts with grips and baskets.
    a = Image.new("RGBA", (14, 14))
    p = a.load()
    for k in range(11):
        p[2 + k, 1 + k] = steel
        p[11 - k, 1 + k] = steel
    for k in range(2):
        p[2 + k, 1 + k] = red
        p[11 - k, 1 + k] = blue
    for x in (11, 12, 13):
        p[x, 11] = dark
    for x in (0, 1, 2):
        p[x, 11] = dark
    sheet.paste(outline(a), (0, 0))
    # Gloves: a red mitt, thumb out, with a grey cuff.
    g = Image.new("RGBA", (14, 14))
    p = g.load()
    for y in range(2, 9):
        for x in range(4, 10):
            p[x, y] = red
    for x in range(5, 9):
        p[x, 1] = red
    for y in range(5, 8):
        p[2, y] = red
        p[3, y] = red
    for y in range(9, 12):
        for x in range(4, 10):
            p[x, y] = rgb("#8a939c") if y != 10 else rgb("#d0d6dc")
    p[6, 4] = rgb("#e05a4a")
    sheet.paste(outline(g), (14, 0))
    # Goggles and buff: two blue lenses on a strap, a striped buff below.
    o = Image.new("RGBA", (14, 14))
    p = o.load()
    for x in range(0, 14):
        p[x, 4] = rgb("#3c3c46")
    for cx in (4, 9):
        for y in range(2, 7):
            for x in range(cx - 2, cx + 2):
                p[x, y] = blue if y > 2 else rgb("#9ccbf0")
    for y in range(8, 12):
        for x in range(2, 12):
            p[x, y] = rgb("#e8a33c") if (x + y) % 3 else rgb("#7a4f9e")
    sheet.paste(outline(o), (28, 0))
    # Crampons: a steel frame with spikes underneath and a strap.
    c = Image.new("RGBA", (14, 14))
    p = c.load()
    for x in range(1, 13):
        p[x, 6] = steel
        p[x, 7] = dark
    for x in range(1, 13, 2):
        p[x, 8] = steel
        p[x, 9] = steel
    p[0, 5] = steel
    p[0, 4] = steel
    for x in range(3, 11):
        p[x, 3] = red
    p[3, 4] = red
    p[3, 5] = red
    p[10, 4] = red
    p[10, 5] = red
    sheet.paste(outline(c), (42, 0))
    # Headlamp: a lamp on an elastic band, its beam lit.
    h = Image.new("RGBA", (14, 14))
    p = h.load()
    for k in range(10):
        p[2 + k, 9] = rgb("#3c3c46")
    for y in range(5, 10):
        for x in range(4, 9):
            p[x, y] = rgb("#e0b03c")
    for y in range(6, 9):
        for x in range(5, 8):
            p[x, y] = rgb("#fff6c8")
    for k in range(4):
        p[9 + k // 2, 6 - k // 2 + (k % 2)] = rgb("#fff6c8")
    sheet.paste(outline(h), (56, 0))
    # Helmet: an orange dome with a strap.
    m = Image.new("RGBA", (14, 14))
    p = m.load()
    for y in range(3, 10):
        for x in range(2, 12):
            if ((x - 6.5) ** 2) / 25 + ((y - 9) ** 2) / 36 <= 1.0:
                p[x, y] = rgb("#e8782c")
    for x in range(1, 13):
        p[x, 9] = rgb("#b8561c")
    p[4, 5] = rgb("#f4a868")
    p[5, 4] = rgb("#f4a868")
    for y in range(10, 12):
        p[3, y] = rgb("#3c3c46")
        p[10, y] = rgb("#3c3c46")
    sheet.paste(outline(m), (70, 0))
    # Rope: a coil, blue with a red fleck.
    r = Image.new("RGBA", (14, 14))
    p = r.load()
    for y in range(14):
        for x in range(14):
            d = ((x - 6.5) ** 2 + (y - 7) ** 2) ** 0.5
            if 3.0 <= d < 5.5 and not (2.5 < d < 3.0):
                p[x, y] = rgb("#3a78c8") if int(d * 2) % 2 else rgb("#6ea6e0")
    p[10, 3] = red
    p[11, 2] = red
    sheet.paste(outline(r), (84, 0))
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
