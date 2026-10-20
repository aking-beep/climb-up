"""
The climbs' props, plants, animals and finds drawn smooth for phones, in the
style of the party and the crag gear: bold rounded shapes, cel shading lit
from the upper left, warm saturated shadows, a crisp dark outline. Each is
drawn at 4x with the same size and frame layout as its pixel version in
godot/assets/terrain/props/, into godot/assets/terrain/props/hd/; the game
(core/world/art.gd) uses the HD one at the pixel size, so layouts and frame
regions do not change.

    python3 tools/art/props_hd.py          # everything
    python3 tools/art/props_hd.py flora    # just the other places' plants and ice
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "assets" / "terrain" / "props" / "hd"
SCALE, SS = 4, 2
K = SCALE * SS
LINE = (32, 22, 24, 255)
O = 0.45


def c(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


class Pen:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w * K, h * K), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.ox = 0

    def at(self, ox):
        self.ox = ox
        return self

    def p(self, x, y):
        return ((self.ox + x) * K, y * K)

    def ellipse(self, x0, y0, x1, y1, fill, outline=True):
        if outline:
            self.d.ellipse([*self.p(x0 - O, y0 - O), *self.p(x1 + O, y1 + O)], fill=LINE)
        self.d.ellipse([*self.p(x0, y0), *self.p(x1, y1)], fill=fill)

    def rrect(self, x0, y0, x1, y1, r, fill, outline=True):
        if outline:
            self.d.rounded_rectangle([*self.p(x0 - O, y0 - O), *self.p(x1 + O, y1 + O)], radius=(r + O) * K, fill=LINE)
        self.d.rounded_rectangle([*self.p(x0, y0), *self.p(x1, y1)], radius=r * K, fill=fill)

    def poly(self, pts, fill, outline=True):
        q = [self.p(x, y) for x, y in pts]
        if outline:
            self.d.line(q + q[:1], fill=LINE, width=int(O * 2.2 * K), joint="curve")
        self.d.polygon(q, fill=fill)

    def line(self, pts, width, fill, outline=True):
        q = [self.p(x, y) for x, y in pts]
        if outline:
            self.d.line(q, fill=LINE, width=int((width + 2 * O) * K), joint="curve")
        self.d.line(q, fill=fill, width=max(1, int(width * K)), joint="curve")

    def save(self, name):
        OUT.mkdir(parents=True, exist_ok=True)
        self.im.resize((self.w * SCALE, self.h * SCALE), Image.LANCZOS).save(OUT / f"{name}.png")


STONE = (c("#cfc6b8"), c("#a39a8c"), c("#77706a"), c("#4e4a48"))


def stone(pen, x0, y0, x1, y1, tones=STONE):
    pen.ellipse(x0, y0, x1, y1, tones[1])
    pen.ellipse(x0 + (x1 - x0) * 0.12, y0 + (y1 - y0) * 0.1, x0 + (x1 - x0) * 0.62, y0 + (y1 - y0) * 0.5, tones[0], outline=False)
    pen.ellipse(x0 + (x1 - x0) * 0.35, y0 + (y1 - y0) * 0.55, x1 - (x1 - x0) * 0.06, y1 - (y1 - y0) * 0.06, tones[2], outline=False)


def cairn():
    p = Pen(16, 20)
    for cy, r in ((16.5, 6.6), (12.0, 5.4), (8.2, 4.4), (5.0, 3.4), (2.6, 2.2)):
        stone(p, 8 - r, cy - r * 0.55, 8 + r, cy + r * 0.55)
    p.save("cairn")


def sign():
    p = Pen(18, 22)
    p.rrect(7.6, 8.0, 10.4, 21.6, 0.6, c("#7a4e2c"))
    p.rrect(8.0, 8.6, 8.9, 21.0, 0.3, c("#9c6a40"), outline=False)
    p.rrect(1.0, 2.0, 17.0, 10.0, 1.4, c("#c8925a"))
    p.rrect(1.6, 2.5, 16.4, 4.4, 0.8, c("#e2b27a"), outline=False)
    for y in (5.8, 7.8):
        p.line([(3.5, y), (14.0 if y < 7 else 11.0, y)], 0.7, c("#5a3418"), outline=False)
    p.save("sign")


def grass(i):
    import random
    rnd = random.Random(40 + i)
    p = Pen(16, 8)
    greens = [c("#7d8c3a"), c("#a2b04c"), c("#c4cc68"), c("#5e6c2c")]
    for k in range(rnd.randint(4, 7)):
        x = rnd.uniform(2, 14)
        hgt = rnd.uniform(3.5, 7.0)
        lean = rnd.uniform(-2.5, 2.5)
        col = greens[rnd.randrange(len(greens))]
        p.line([(x, 8.0), (x + lean * 0.4, 8 - hgt * 0.6), (x + lean, 8 - hgt)], 0.9, col)
    p.save(f"grass_{i}")


def pebbles(i):
    import random
    rnd = random.Random(70 + i)
    p = Pen(16, 6)
    for k in range(rnd.randint(2, 4)):
        x, r = rnd.uniform(3, 13), rnd.uniform(1.3, 2.4)
        stone(p, x - r, 6 - r * 1.6, x + r, 5.6)
    p.save(f"pebbles_{i}")


def groundsel():
    p = Pen(28, 48)
    # The trunk wrapped in a skirt of dead leaves.
    p.rrect(10.6, 15.0, 17.4, 47.6, 2.4, c("#7c6448"))
    for y in range(18, 46, 3):
        p.line([(10.8, y), (17.2, y + 1.2)], 1.0, c("#a88a62"), outline=False)
    p.rrect(11.2, 15.4, 12.6, 47.0, 0.6, c("#9a7c58"), outline=False)
    # Rosettes of big leaves.
    for cx, cy, r in ((7.0, 12.0, 7.0), (20.5, 10.5, 7.0), (14.0, 6.0, 6.4)):
        for a in range(0, 360, 40):
            ang = math.radians(a)
            ex, ey = cx + math.cos(ang) * r * 0.55, cy + math.sin(ang) * r * 0.35
            p.ellipse(ex - r * 0.5, ey - r * 0.22, ex + r * 0.5, ey + r * 0.22, c("#4f8a34"))
        p.ellipse(cx - r * 0.45, cy - r * 0.3, cx + r * 0.45, cy + r * 0.3, c("#7cb84a"))
        p.ellipse(cx - r * 0.3, cy - r * 0.28, cx + r * 0.05, cy - r * 0.02, c("#a8d86a"), outline=False)
    p.save("groundsel")


def lobelia():
    p = Pen(10, 26)
    p.ellipse(0.6, 2.6, 9.4, 25.6, c("#4f7a52"))
    for y in range(5, 25, 2):
        w = 4.0 - abs(y - 14) * 0.12
        p.line([(5 - w, y), (5, y + 0.8), (5 + w, y)], 0.6, c("#7fa874"), outline=False)
    p.ellipse(2.0, 4.0, 4.2, 18.0, c("#9cc48a", 160), outline=False)
    p.save("lobelia")


def rest_stone():
    p = Pen(26, 12)
    stone(p, 0.6, 1.6, 25.4, 11.4)
    p.save("rest_stone")


def exit_post():
    p = Pen(14, 30)
    p.rrect(2.6, 2.0, 5.0, 29.6, 0.8, c("#7a4e2c"))
    p.poly([(5.2, 3.0), (13.4, 6.2), (5.2, 9.4)], c("#e04a30"))
    p.poly([(5.6, 3.6), (11.0, 5.6), (5.6, 6.0)], c("#ff7a5a"), outline=False)
    p.save("exit_post")


def tent(color, dark, light, name):
    p = Pen(32, 24)
    p.line([(1.0, 23.4), (6.0, 12.0)], 0.4, c("#d8d0c0"), outline=False)
    p.line([(31.0, 23.4), (26.0, 12.0)], 0.4, c("#d8d0c0"), outline=False)
    p.poly([(3.0, 23.4), (8.0, 9.0), (16.0, 3.0), (24.0, 9.0), (29.0, 23.4)], c(color))
    p.poly([(16.0, 3.4), (24.0, 9.0), (28.6, 23.0), (18.0, 23.0)], c(dark), outline=False)
    p.poly([(8.4, 9.4), (16.0, 3.6), (12.0, 12.0)], c(light), outline=False)
    p.poly([(12.0, 23.4), (15.6, 13.0), (19.2, 23.4)], c("#2a1c1a"))
    p.line([(16.0, 3.0), (16.0, 1.0)], 0.6, c("#5a5048"))
    p.save(name)


def fg_boulder():
    p = Pen(64, 40)
    p.poly([(0, 39.6), (5.0, 14.0), (19.0, 4.0), (38.0, 2.0), (55.0, 12.0), (63.6, 39.6)], c("#1c1618"))
    p.line([(5.0, 14.0), (19.0, 4.0), (38.0, 2.0), (46.0, 6.0)], 1.0, c("#4a3c38"), outline=False)
    p.save("fg_boulder")


def fire():
    p = Pen(128, 24)
    for f in range(4):
        q = p.at(f * 32)
        q.ellipse(4.0, 18.0, 28.0, 23.4, c("#ffb14a", 90), outline=False)
        q.rrect(7.0, 19.2, 25.0, 22.4, 1.4, c("#6a4228"))
        q.rrect(9.0, 18.0, 23.0, 20.6, 1.2, c("#8a5a34"))
        sway = math.sin(f * math.pi / 2) * 1.2
        q.poly([(10.0, 19.0), (12.0 + sway, 9.0), (16.0, 3.0 + f % 2), (20.0 - sway, 9.0), (22.0, 19.0)], c("#e8462a"))
        q.poly([(12.0, 19.0), (14.0 + sway, 11.0), (16.0, 7.0), (18.0 - sway, 11.0), (20.0, 19.0)], c("#ff9a2e"), outline=False)
        q.poly([(14.0, 19.0), (15.4 + sway * 0.5, 13.0), (16.0, 10.5), (16.8, 13.0), (18.0, 19.0)], c("#ffe27a"), outline=False)
    p.at(0).save("fire")


def rock():
    p = Pen(10, 10)
    stone(p, 0.8, 1.0, 9.2, 9.2, (c("#c9b49a"), c("#9c8670"), c("#6e5a4a"), c("#4a3a30")))
    p.save("rock")


def water():
    p = Pen(12, 14)
    p.rrect(0.8, 11.8, 11.2, 13.6, 0.6, c("#7a6a5a"))
    p.rrect(2.0, 3.6, 10.0, 12.0, 2.0, c("#3f86c8"))
    p.rrect(2.6, 4.2, 4.8, 11.2, 1.0, c("#7cc0f0"), outline=False)
    p.rrect(3.8, 1.2, 8.2, 3.8, 0.8, c("#f2efe6"))
    p.ellipse(5.6, 6.6, 6.8, 8.6, c("#ffffff", 220), outline=False)
    p.save("water")


def gear():
    """Five pieces of gear in GEAR_KINDS order (climb_level.gd): trekking
    poles, gloves, goggles and buff, crampons, headlamp."""
    p = Pen(98, 14)
    steel, steel_d = c("#c8d0d8"), c("#8a949e")
    # Trekking poles, crossed: grips (red, blue), shafts, baskets.
    q = p.at(0)
    q.line([(2.6, 2.4), (11.6, 12.4)], 0.9, steel)
    q.line([(11.4, 2.4), (2.4, 12.4)], 0.9, steel)
    q.line([(2.0, 1.6), (4.0, 3.8)], 1.4, c("#d64a3a"))
    q.line([(12.0, 1.6), (10.0, 3.8)], 1.4, c("#3a78c8"))
    q.ellipse(9.8, 10.8, 12.8, 12.0, c("#4a4a52"))
    q.ellipse(1.2, 10.8, 4.2, 12.0, c("#4a4a52"))
    # A red mitt with a grey cuff.
    q = p.at(14)
    q.rrect(3.6, 1.4, 10.4, 9.6, 3.0, c("#d64a3a"))
    q.ellipse(1.4, 4.4, 5.0, 8.2, c("#d64a3a"))
    q.rrect(4.4, 2.4, 6.6, 6.0, 1.0, c("#f07a64"), outline=False)
    q.rrect(3.4, 9.4, 10.6, 12.8, 0.8, c("#9aa4ae"))
    q.line([(3.8, 11.0), (10.2, 11.0)], 0.5, c("#d8dde2"), outline=False)
    # Goggles over a striped buff.
    q = p.at(28)
    q.rrect(1.4, 8.0, 12.6, 12.8, 1.6, c("#e8a33c"))
    for x in (3.4, 6.4, 9.4):
        q.line([(x, 8.4), (x + 1.4, 12.4)], 0.8, c("#7a4f9e"), outline=False)
    q.line([(0.6, 4.6), (13.4, 4.6)], 1.0, c("#3c3c46"))
    q.rrect(1.8, 2.2, 6.6, 7.0, 2.0, c("#3a78c8"))
    q.rrect(7.4, 2.2, 12.2, 7.0, 2.0, c("#3a78c8"))
    q.rrect(2.4, 2.8, 4.2, 4.4, 0.8, c("#a8d8f8"), outline=False)
    q.rrect(8.0, 2.8, 9.8, 4.4, 0.8, c("#a8d8f8"), outline=False)
    # Crampons: a steel frame, spikes below, a red strap.
    q = p.at(42)
    q.line([(4.0, 6.4), (4.0, 3.2), (10.0, 3.2), (10.0, 6.4)], 1.0, c("#d64a3a"))
    q.rrect(1.2, 6.0, 12.8, 8.0, 0.8, steel)
    for x in (2.0, 4.4, 6.8, 9.2, 11.6):
        q.poly([(x - 0.8, 8.0), (x + 0.8, 8.0), (x, 11.2)], steel_d)
    q.poly([(0.4, 6.4), (1.4, 6.0), (0.2, 4.0)], steel_d)
    # Headlamp: an elastic band and a lamp, its beam lit.
    q = p.at(56)
    q.poly([(8.6, 5.6), (13.8, 3.0), (13.8, 11.0), (8.6, 8.4)], c("#fff2a8", 150), outline=False)
    q.line([(0.8, 9.6), (3.0, 7.4), (8.6, 7.4)], 1.2, c("#3c3c46"))
    q.rrect(3.4, 4.4, 9.0, 10.2, 1.4, c("#e0b03c"))
    q.ellipse(5.0, 5.6, 8.4, 9.0, c("#fff6c8"), outline=False)
    # Helmet: an orange dome, a brim, a dark strap.
    q = p.at(70)
    q.line([(3.6, 9.6), (4.6, 12.2)], 0.7, c("#3c3c46"))
    q.line([(10.4, 9.6), (9.4, 12.2)], 0.7, c("#3c3c46"))
    q.poly([(1.4, 9.6), (2.4, 5.4), (5.0, 2.8), (9.0, 2.8), (11.6, 5.4), (12.6, 9.6)], c("#e8782c"))
    q.rrect(0.8, 9.0, 13.2, 10.6, 0.6, c("#b8561c"))
    q.ellipse(3.6, 4.0, 6.4, 6.4, c("#f4a868"), outline=False)
    # Rope: a coil, with the end tucked through.
    q = p.at(84)
    q.ellipse(1.6, 2.2, 12.4, 12.0, c("#3a78c8"))
    q.ellipse(4.0, 4.6, 10.0, 9.6, (0, 0, 0, 0), outline=True)
    q.ellipse(4.4, 5.0, 9.6, 9.2, (0, 0, 0, 0), outline=False)
    q.line([(2.6, 7.0), (11.4, 7.0)], 0.5, c("#6ea6e0"), outline=False)
    q.line([(9.6, 3.4), (12.4, 1.2)], 0.9, c("#d64a3a"))
    p.at(0).save("gear")


def artifact():
    """A small banded clay pot in a soft glow (see godot_hazards.artifact)."""
    p = Pen(24, 12)
    for f in range(2):
        q = p.at(f * 12)
        q.ellipse(0.6, 1.4, 11.4, 12.0, c("#ffe08a", 60 if f == 0 else 120), outline=False)
        q.poly([(4.2, 2.2), (7.8, 2.2), (7.4, 3.4), (9.2, 5.2), (9.2, 8.8), (7.8, 10.8), (4.2, 10.8), (2.8, 8.8), (2.8, 5.2), (4.6, 3.4)], c("#b5643a"))
        q.poly([(2.9, 5.9), (9.1, 5.9), (9.1, 7.6), (2.9, 7.6)], c("#efe2c4"), outline=False)
        for i in range(3):
            x = 3.6 + i * 2.0
            q.poly([(x, 7.6), (x + 0.9, 6.0), (x + 1.8, 7.6)], c("#c23a2a"), outline=False)
        if f:
            q.poly([(9.6, 0.2), (10.0, 1.4), (11.2, 1.8), (10.0, 2.2), (9.6, 3.4), (9.2, 2.2), (8.0, 1.8), (9.2, 1.4)], c("#ffffff"), outline=False)
    p.at(0).save("artifact")


def thistle():
    p = Pen(32, 16)
    q = p.at(0)
    for a in (-60, -30, 0, 30, 60):
        ang = math.radians(a - 90)
        q.poly([(8, 15.6), (8 + math.cos(ang - 0.25) * 7, 15.6 + math.sin(ang - 0.25) * 7), (8 + math.cos(ang) * 9, 15.6 + math.sin(ang) * 9), (8 + math.cos(ang + 0.25) * 7, 15.6 + math.sin(ang + 0.25) * 7)], c("#6f9a56"))
    q.ellipse(5.2, 2.0, 10.8, 7.6, c("#a24fc0"))
    q.ellipse(6.0, 2.6, 8.6, 4.8, c("#d08ae6"), outline=False)
    for k in range(5):
        q.line([(5.4 + k * 1.3, 2.4), (5.0 + k * 1.5, 0.4)], 0.35, c("#e8c4f2"), outline=False)
    q = p.at(16)
    for x, y, r in ((4.0, 10.0, 3.6), (11.0, 9.0, 3.8), (8.0, 4.6, 3.6), (7.4, 12.6, 3.2)):
        q.poly([(x, y - r), (x + r * 0.8, y), (x, y + r * 0.9), (x - r * 0.8, y)], c("#4f9a3c"))
        q.line([(x, y - r * 0.8), (x, y + r * 0.7)], 0.3, c("#8ccf6a"), outline=False)
    p.at(0).save("thistle")


def ants():
    p = Pen(72, 6)
    for f in range(3):
        q = p.at(f * 24)
        for k in range(4):
            x = 2.0 + k * 5.6 + (f % 2) * 0.6
            for leg in (-1, 1):
                q.line([(x + 1.6, 4.2), (x + 1.6 + leg * 1.4, 5.8 if (f + k) % 2 else 5.2)], 0.3, c("#2a140c"), outline=False)
            q.ellipse(x, 2.6, x + 1.8, 4.6, c("#7a2a14"))
            q.ellipse(x + 1.6, 2.8, x + 3.0, 4.4, c("#5a1e10"))
            q.ellipse(x + 2.8, 2.4, x + 4.4, 4.2, c("#8a3418"))
    p.at(0).save("ants")


def raven():
    p = Pen(36, 12)
    for f in range(2):
        q = p.at(f * 18)
        up = f == 0
        q.poly([(6.0, 5.0), (2.0, 0.6 if up else 10.6), (10.0, 5.0)], c("#26222c"))
        q.ellipse(3.0, 4.2, 14.0, 8.8, c("#2c2832"))
        q.ellipse(11.0, 3.4, 15.4, 7.0, c("#2c2832"))
        q.rrect(9.4, 4.4, 11.6, 7.4, 0.8, c("#f2f0ea"), outline=False)
        q.poly([(15.2, 4.6), (17.6, 5.4), (15.2, 6.2)], c("#4a4038"))
        q.ellipse(13.2, 4.2, 14.2, 5.2, c("#ffd65a"), outline=False)
        q.poly([(3.4, 6.0), (0.4, 7.6), (3.6, 7.8)], c("#26222c"))
        q.poly([(7.0, 5.2), (11.0 if up else 9.0, 0.8 if up else 11.0), (12.0, 5.6)], c("#3a3640"))
    p.at(0).save("raven")


# --- Plants and ice of the other places (tools/levels/route_levels.py) -------

def tree(i):
    """A podocarpus of the Umbwe forest, hung with old man's beard."""
    w, h = (40, 80) if i == 0 else (34, 66)
    p = Pen(w, h)
    cx = w / 2
    p.poly([(cx - 3.2, h - 0.4), (cx - 2.2, h * 0.42), (cx + 2.4, h * 0.42), (cx + 3.4, h - 0.4)], c("#4a3426"))
    p.line([(cx - 1.4, h - 2), (cx - 1.0, h * 0.46)], 0.8, c("#6a4c36"), outline=False)
    p.line([(cx, h * 0.6), (cx - w * 0.3, h * 0.44)], 1.4, c("#4a3426"))
    p.line([(cx, h * 0.52), (cx + w * 0.32, h * 0.38)], 1.4, c("#4a3426"))
    rnd = [0.0, 0.7, 0.3, 0.9, 0.5, 0.2]
    blobs = [(cx - w * 0.28, h * 0.36, w * 0.24), (cx + w * 0.26, h * 0.3, w * 0.24),
             (cx - w * 0.05, h * 0.18, w * 0.3), (cx + w * 0.08, h * 0.38, w * 0.22)]
    for bx, by, r in blobs:
        p.ellipse(bx - r, by - r * 0.7, bx + r, by + r * 0.7, c("#24452c"))
    for k, (bx, by, r) in enumerate(blobs):
        p.ellipse(bx - r * 0.7, by - r * 0.6, bx + r * 0.3, by + r * 0.1, c("#3c6a3c"), outline=False)
        p.ellipse(bx - r * 0.5, by - r * 0.5, bx - r * 0.05, by - r * 0.15, c("#5c8c4c"), outline=False)
        # Old man's beard: pale strands hanging from the crown.
        for j in range(4):
            sx = bx - r * 0.6 + j * r * 0.4
            ln = r * (0.6 + rnd[(k + j) % 6])
            p.line([(sx, by + r * 0.4), (sx + 0.4, by + r * 0.4 + ln)], 0.7, c("#b8c4a0", 220), outline=False)
    p.save(f"tree_{i}")


def heather():
    """Giant heather of the Shira moorland: twiggy, lichen-grey and olive."""
    p = Pen(22, 30)
    for x0, x1 in ((11, 4), (11, 18), (11, 9), (11, 14)):
        p.line([(x0, 29.6), (x1, 12)], 1.0, c("#5a4632"))
    for cx, cy, r in ((5, 11, 4.6), (17, 10, 4.8), (11, 6, 5.2), (9, 15, 4.0), (14, 15, 4.0)):
        p.ellipse(cx - r, cy - r * 0.8, cx + r, cy + r * 0.8, c("#5f6e36"))
        p.ellipse(cx - r * 0.6, cy - r * 0.6, cx + r * 0.2, cy, c("#869448"), outline=False)
        p.ellipse(cx - r * 0.3, cy - r * 0.5, cx + r * 0.1, cy - r * 0.15, c("#c8c8a0", 200), outline=False)
    p.save("heather")


def protea():
    """A Kilimanjaro protea: a low shrub with a pale pink cup."""
    p = Pen(14, 14)
    for a in (-0.9, -0.3, 0.3, 0.9):
        p.line([(7, 13.6), (7 + a * 6, 7)], 0.8, c("#4c6a3a"))
    p.ellipse(1.0, 6.0, 6.0, 9.0, c("#5a7a40"))
    p.ellipse(8.0, 6.4, 13.0, 9.4, c("#5a7a40"))
    p.ellipse(4.2, 1.0, 9.8, 7.0, c("#e8b8b0"))
    p.ellipse(5.4, 2.0, 8.6, 4.8, c("#fff0e0"), outline=False)
    p.save("protea")


def roots():
    """Roots across the forest floor."""
    p = Pen(30, 10)
    p.line([(0.6, 9.4), (6, 5.4), (13, 6.6), (20, 4.2), (29.4, 8.8)], 1.6, c("#5a3e2a"))
    p.line([(8, 9.6), (12, 6.8)], 1.2, c("#5a3e2a"))
    p.line([(18, 9.6), (20.4, 5.0)], 1.2, c("#5a3e2a"))
    p.line([(2, 8.6), (6, 5.0), (12, 6.0)], 0.5, c("#8a6a4a"), outline=False)
    p.ellipse(13, 3.0, 17, 6.0, c("#4c7a3c"))
    p.save("roots")


def serac():
    """A block of glacier ice: cold blue shadow, white top, a crack."""
    p = Pen(22, 30)
    p.poly([(1, 29.6), (2.4, 9), (8, 2), (15, 1), (20.6, 7), (21, 29.6)], c("#a8cce8"))
    p.poly([(12, 1.4), (15, 1.2), (20.4, 7.2), (20.6, 29.2), (13.6, 29.2)], c("#7aa8d0"), outline=False)
    p.poly([(2.6, 9.4), (8.2, 2.4), (14, 1.6), (10, 6), (4, 11)], c("#f2fbff"), outline=False)
    p.line([(9, 8), (11, 15), (9.4, 22)], 0.5, c("#5a88b8"), outline=False)
    for y in (14, 20, 25):
        p.line([(3, y), (12, y + 0.6)], 0.3, c("#d8eefc", 180), outline=False)
    p.save("serac")


def vent():
    """A fumarole on the crater floor: yellow sulphur round a warm hole."""
    p = Pen(16, 10)
    p.ellipse(0.6, 3.0, 15.4, 9.6, c("#9a8a5a"))
    p.ellipse(2.4, 4.0, 13.6, 9.0, c("#d8c050"), outline=False)
    p.ellipse(5.4, 5.0, 10.6, 8.0, c("#3a3028"))
    p.ellipse(3.4, 4.4, 6.0, 5.8, c("#f4e080"), outline=False)
    p.save("vent")


def branch():
    """A dead branch coming down through the forest (the forest's stonefall)."""
    p = Pen(10, 10)
    p.line([(1, 8.6), (9, 1.4)], 1.4, c("#6a4a32"))
    p.line([(5, 5), (8.6, 7)], 0.8, c("#6a4a32"))
    p.line([(1.6, 8), (8.4, 2)], 0.5, c("#9a7652"), outline=False)
    p.save("branch")


def flora():
    tree(0); tree(1); heather(); protea(); roots(); serac(); vent(); branch()
    print("wrote flora to", OUT)


def main():
    cairn(); sign(); groundsel(); lobelia(); rest_stone(); exit_post(); fg_boulder()
    for i in range(4):
        grass(i)
    for i in range(3):
        pebbles(i)
    tent("#f08a2a", "#c4621a", "#ffb45a", "tent_orange")
    tent("#3e86d8", "#2a60a8", "#7ab4f0", "tent_blue")
    fire(); rock(); water(); gear(); artifact(); thistle(); ants(); raven()
    print("wrote props to", OUT)


if __name__ == "__main__":
    import sys
    flora() if sys.argv[1:] == ["flora"] else main()
