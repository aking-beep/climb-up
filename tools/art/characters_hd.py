"""
The party, drawn smooth for phones: You, Marco, Lena and Jun as clean
illustrated characters (rounded shapes, a big readable head, cel shading
lit from the upper left, a warm rim light and a crisp dark outline), not
pixel sprites. Same poses and frame layout as tools/art/characters.py
(27 frames, 8 columns, feet at the bottom centre), drawn at 4x: 128 x 160
px frames that the game shows at a quarter scale with smooth filtering, so
on a phone's screen the figure is drawn at full resolution.

Shapes are drawn at 8x and scaled down by 2 for anti-aliased edges.

    python3 tools/art/characters_hd.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

from characters import FRAMES, PARTY, LEG, ARM, LEAN, DROP, GROUND, CX, W, H, COLS, hex_rgb

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "assets" / "characters"
SCALE = 4          # final texels per world pixel
SS = 2             # supersampling on top of that
K = SCALE * SS     # drawing units per world pixel
LINE = (34, 24, 30, 255)
OUT_W = 0.68       # outline width, world px: bold, as mobile games draw people

SKIN = ("#f9d9b0", "#e9b688", "#c98f62")
PANTS = ("#5e5246", "#4a4038", "#352e28")
BOOT = ("#9c6a3e", "#734a28", "#4a2e18")
PACK = ("#c09a5c", "#93723f", "#64492a")
MAT = ("#69b3cc", "#3f8199")
GLOVE = ("#b07a4a", "#7e5432")
LAMP = ("#e4e8ea", "#9aa2a8", "#ffe27a")
HARNESS = ("#e8402e", "#a8261a", "#ff7a5c")   # a red harness: belt, dark edge, highlight
CHALK = ("#3a6fd0", "#f4f1ea")                 # chalk bag and its rim


def c(h, a=255):
    return tuple(hex_rgb(h)) + (a,)


class Pen:
    """Draws in world units (the 32 x 40 frame) at K times the size."""

    def __init__(self, d, ox, oy):
        self.d, self.ox, self.oy = d, ox, oy

    def p(self, x, y):
        return ((self.ox + x) * K, (self.oy + y) * K)

    def capsule(self, pts, width, fill, outline=True):
        q = [self.p(x, y) for x, y in pts]
        if outline:
            self.d.line(q, fill=LINE, width=int((width + OUT_W * 2) * K), joint="curve")
            for x, y in pts[:1] + pts[-1:]:
                self.dot(x, y, width / 2 + OUT_W, LINE)
        self.d.line(q, fill=fill, width=int(width * K), joint="curve")
        for x, y in pts[:1] + pts[-1:]:
            self.dot(x, y, width / 2, fill)
        for x, y in pts[1:-1]:
            self.dot(x, y, width / 2, fill)

    def dot(self, x, y, r, fill):
        cx, cy = self.p(x, y)
        self.d.ellipse([cx - r * K, cy - r * K, cx + r * K, cy + r * K], fill=fill)

    def ellipse(self, x0, y0, x1, y1, fill, outline=False):
        if outline:
            self.d.ellipse([*self.p(x0 - OUT_W, y0 - OUT_W), *self.p(x1 + OUT_W, y1 + OUT_W)], fill=LINE)
        self.d.ellipse([*self.p(x0, y0), *self.p(x1, y1)], fill=fill)

    def rrect(self, x0, y0, x1, y1, r, fill, outline=False):
        if outline:
            self.d.rounded_rectangle([*self.p(x0 - OUT_W, y0 - OUT_W), *self.p(x1 + OUT_W, y1 + OUT_W)], radius=(r + OUT_W) * K, fill=LINE)
        self.d.rounded_rectangle([*self.p(x0, y0), *self.p(x1, y1)], radius=r * K, fill=fill)

    def poly(self, pts, fill):
        self.d.polygon([self.p(x, y) for x, y in pts], fill=fill)

    def chord(self, x0, y0, x1, y1, start, end, fill):
        self.d.chord([*self.p(x0, y0), *self.p(x1, y1)], start, end, fill=fill)


def joints(f):
    """The pose's joints in world px, as characters.py places them."""
    hx = CX + (f["hip"][0] - 8) * 1.4
    hy = GROUND - 10 - ((16 - f["hip"][1]) * -DROP) if f["hip"][1] >= 16 else GROUND - 10 - (16 - f["hip"][1]) * 1.2
    sx, sy = hx + f["lean"] * LEAN, hy - 8

    def foot(i):
        fx, fy = f["legs"][i]
        return hx + fx * LEG, GROUND + fy * LEG

    def knee(i):
        k = f["knees"][i] if f["knees"] and f["knees"][i] else None
        if k:
            return hx + k[0] * LEG, hy + 5 + k[1] * LEG
        fx, fy = foot(i)
        return (hx + fx) / 2 + 1, (hy + fy) / 2

    def hand(i):
        ax, ay = f["arms"][i]
        return sx + 1 + ax * ARM, sy + 2 + ay * (2.0 if ay < 0 else ARM)

    def elbow(i):
        x2, y2 = hand(i)
        bend = 1 if y2 > sy else -1
        return (sx + 1 + x2) / 2 - (0.6 if bend < 0 else 0), (sy + 2 + y2) / 2 + bend

    return hx, hy, sx, sy, foot, knee, hand, elbow


def draw(pen: Pen, f: dict, who: dict):
    jl, jm, jd = [c(x) for x in who["jacket"]]
    hl, hm, hd = [c(x) for x in who["hat"]]
    hair, hair_d = [c(x) for x in who["hair"]]
    trim = c(who["trim"])
    hx, hy, sx, sy, foot, knee, hand, elbow = joints(f)

    def boot(x, y, tone):
        # Big, chunky boots: they read at phone size.
        pen.rrect(x - 2.4, y - 3.0, x + 3.4, y, 1.2, c(BOOT[tone]), outline=True)
        pen.rrect(x - 2.4, y - 0.8, x + 3.4, y, 0.4, c("#2b2420"))
        pen.capsule([(x - 1.4, y - 2.3), (x + 1.8, y - 2.3)], 0.6, c(BOOT[0]), outline=False)

    def leg_loop(hip, knee):
        # A harness leg loop around the thigh, a third of the way down.
        t = 0.34
        cx, cy = hip[0] + (knee[0] - hip[0]) * t, hip[1] + (knee[1] - hip[1]) * t
        dx, dy = knee[0] - hip[0], knee[1] - hip[1]
        n = (dx * dx + dy * dy) ** 0.5 or 1
        nx, ny = -dy / n, dx / n
        a, b = (cx - nx * 2.1, cy - ny * 2.1), (cx + nx * 2.1, cy + ny * 2.1)
        pen.capsule([a, b], 1.0, c(HARNESS[0]))
        pen.capsule([(a[0] + 0.2, a[1] - 0.3), (b[0] + 0.2, b[1] - 0.3)], 0.35, c(HARNESS[2]), outline=False)

    # Back leg and arm, in shade.
    bf = foot(1)
    pen.capsule([(hx - 0.8, hy + 0.5), knee(1), (bf[0], bf[1] - 2.2)], 3.3, c(PANTS[2]))
    leg_loop((hx - 0.8, hy + 0.5), knee(1))
    boot(bf[0], bf[1], 2)
    pen.capsule([(sx - 0.6, sy + 1.6), elbow(1), hand(1)], 2.5, jd)
    bh = hand(1)
    pen.dot(bh[0], bh[1], 1.45 + OUT_W, LINE)
    pen.dot(bh[0], bh[1], 1.45, c(GLOVE[1]))
    # Chalk bag at the back of the harness.
    pen.rrect(hx - 4.6, hy - 1.0, hx - 1.8, hy + 2.6, 0.9, c(CHALK[0]), outline=True)
    pen.rrect(hx - 4.8, hy - 1.4, hx - 1.6, hy - 0.4, 0.5, c(CHALK[1]), outline=False)

    # Pack: body, lid, a rolled mat on top.
    px0, py0 = sx - 7.2, sy - 0.6
    pen.rrect(px0, py0, px0 + 5.2, py0 + 9.0, 1.8, c(PACK[1]), outline=True)
    pen.rrect(px0 + 0.6, py0 + 0.6, px0 + 2.2, py0 + 8.2, 0.8, c(PACK[0]))
    pen.rrect(px0 + 0.6, py0 + 4.0, px0 + 4.6, py0 + 6.0, 0.6, c(PACK[2]))
    pen.rrect(px0 - 0.4, py0 - 2.6, px0 + 5.6, py0 - 0.2, 1.2, c(MAT[0]), outline=True)
    pen.capsule([(px0 + 0.6, py0 - 1.9), (px0 + 4.6, py0 - 1.9)], 0.5, c("#a6dbe9"), outline=False)

    # Torso: a rounded jacket, lit on its back edge, the zip and collar.
    pen.capsule([(sx + 0.6, sy + 1.4), (hx + 0.5, hy + 0.6)], 7.6, jm)
    pen.capsule([(sx - 1.8, sy + 1.6), (hx - 1.8, hy + 0.4)], 2.0, jl, outline=False)
    pen.capsule([(sx + 3.4, sy + 2.2), (hx + 3.2, hy + 0.8)], 1.2, jd, outline=False)
    pen.capsule([(sx + 2.0, sy + 1.0), (hx + 1.9, hy + 0.6)], 0.45, trim, outline=False)
    # Chest strap.
    pen.capsule([(sx - 2.4, sy + 4.2), (sx + 3.0, sy + 4.2)], 0.6, c(PACK[2]), outline=False)

    # Front leg and boot.
    ff = foot(0)
    pen.capsule([(hx + 0.8, hy + 0.5), knee(0), (ff[0], ff[1] - 2.2)], 3.5, c(PANTS[0]))
    leg_loop((hx + 0.8, hy + 0.5), knee(0))
    boot(ff[0], ff[1], 1)
    # The harness: a red waist belt with a highlight, the belay loop at the
    # front, a gear loop at the side with two quickdraws hanging.
    pen.capsule([(hx - 3.6, hy + 1.2), (hx + 4.2, hy + 1.2)], 1.7, c(HARNESS[0]))
    pen.capsule([(hx - 3.2, hy + 0.7), (hx + 3.8, hy + 0.7)], 0.45, c(HARNESS[2]), outline=False)
    pen.capsule([(hx - 3.2, hy + 1.8), (hx + 3.8, hy + 1.8)], 0.4, c(HARNESS[1]), outline=False)
    pen.d.ellipse([*pen.p(hx + 2.6 - OUT_W, hy + 1.6 - OUT_W), *pen.p(hx + 4.6 + OUT_W, hy + 3.8 + OUT_W)], fill=LINE)
    pen.d.ellipse([*pen.p(hx + 2.6, hy + 1.6), *pen.p(hx + 4.6, hy + 3.8)], fill=c(HARNESS[1]))
    pen.d.ellipse([*pen.p(hx + 3.1, hy + 2.1), *pen.p(hx + 4.1, hy + 3.3)], fill=c(who["jacket"][1]))
    for gx, col in ((hx - 2.6, "#4aa3ff"), (hx - 1.0, "#ffd23a")):
        pen.capsule([(gx, hy + 1.8), (gx, hy + 3.4)], 0.6, c(col))
        pen.dot(gx, hy + 4.2, 0.75 + OUT_W, LINE)
        pen.dot(gx, hy + 4.2, 0.75, c("#c9ccd2"))

    # Head: big, round and friendly.
    tilt = f["head_tilt"] * 1.4
    cx, cy = sx + 1.2 + tilt, sy - 5.6
    r = 5.0
    # Hair at the back, under the hat.
    pen.ellipse(cx - r - 0.6, cy - r + 1.0, cx + 1.0, cy + r - 0.6, hair, outline=True)
    if who.get("braid"):
        pen.capsule([(cx - 4.8, cy + 2.0), (cx - 6.2, cy + 7.6)], 1.8, hair)
        pen.dot(cx - 6.2, cy + 7.8, 0.8, trim)
    pen.ellipse(cx - r + 0.6, cy - r + 0.6, cx + r, cy + r, c(SKIN[0]), outline=True)
    pen.chord(cx - r + 0.6, cy - r + 0.6, cx + r, cy + r, 20, 120, c(SKIN[1]))
    pen.ellipse(cx - r + 1.4, cy - r + 1.4, cx + r - 0.6, cy + r - 1.4, c(SKIN[0]))
    pen.ellipse(cx - 2.4, cy + 0.2, cx - 1.2, cy + 1.8, c(SKIN[1]))  # ear
    # Hair fringe at the back of the face.
    pen.chord(cx - r - 0.6, cy - r + 1.0, cx + 1.0, cy + r - 0.6, 150, 250, hair)
    # Face: one big eye (side view) with a catch-light, brow, cheek, mouth.
    pen.ellipse(cx + 1.6, cy - 0.6, cx + 3.0, cy + 1.6, LINE)
    pen.ellipse(cx + 2.1, cy - 0.4, cx + 2.7, cy + 0.2, (255, 255, 255, 255))
    pen.capsule([(cx + 1.3, cy - 1.7), (cx + 3.1, cy - 1.9)], 0.5, hair_d, outline=False)
    pen.ellipse(cx + 2.4, cy + 2.0, cx + 4.0, cy + 3.0, (236, 140, 128, 150))
    pen.capsule([(cx + 3.0, cy + 3.4), (cx + 3.9, cy + 3.3)], 0.4, c(SKIN[2]), outline=False)
    # Beanie: crown, a folded band, a bobble, and the headlamp on the band.
    pen.chord(cx - r - 0.2 - OUT_W, cy - r - 1.6 - OUT_W, cx + r + 0.4 + OUT_W, cy + r - 0.8 + OUT_W, 180, 360, LINE)
    pen.chord(cx - r - 0.2, cy - r - 1.6, cx + r + 0.4, cy + r - 0.8, 180, 360, hm)
    pen.chord(cx - r + 0.6, cy - r - 0.8, cx + 1.0, cy + 2.0, 190, 260, hl)
    pen.rrect(cx - r - 0.4, cy - 2.2, cx + r + 0.6, cy - 0.4, 0.8, hd, outline=True)
    pen.dot(cx - 0.4, cy - r - 1.6, 1.5 + OUT_W, LINE)
    pen.dot(cx - 0.4, cy - r - 1.6, 1.5, hl)
    pen.rrect(cx + r - 0.6, cy - 2.6, cx + r + 1.6, cy - 0.2, 0.6, c(LAMP[1]), outline=True)
    pen.dot(cx + r + 1.2, cy - 1.4, 0.55, c(LAMP[2]))

    # Front arm last, with a glove.
    pen.capsule([(sx + 1.2, sy + 1.6), elbow(0), hand(0)], 2.7, jl)
    pen.capsule([(sx + 0.8, sy + 1.2), elbow(0)], 0.9, c(who["jacket"][0]), outline=False)
    fh = hand(0)
    pen.dot(fh[0], fh[1], 1.6 + OUT_W, LINE)
    pen.dot(fh[0], fh[1], 1.6, c(GLOVE[0]))
    pen.dot(fh[0] - 0.4, fh[1] - 0.4, 0.6, c("#d6a070"))


def main():
    rows = (len(FRAMES) + COLS - 1) // COLS
    OUT.mkdir(parents=True, exist_ok=True)
    for name, who in PARTY.items():
        big = Image.new("RGBA", (W * COLS * K, H * rows * K), (0, 0, 0, 0))
        d = ImageDraw.Draw(big)
        for index, f in enumerate(FRAMES):
            draw(Pen(d, (index % COLS) * W, (index // COLS) * H), f, who)
        sheet = big.resize((W * COLS * SCALE, H * rows * SCALE), Image.LANCZOS)
        sheet.save(OUT / f"{name}-hd.png")
        print("wrote", OUT / f"{name}-hd.png")


if __name__ == "__main__":
    main()
