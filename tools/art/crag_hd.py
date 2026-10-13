"""
The crag's gear and holds, drawn smooth for phones like the party
(tools/art/characters_hd.py): rounded shapes, cel shading lit from the upper
left, a crisp dark outline, at 4x and shown at a quarter scale with smooth
filtering. Sizes below are world px.

  godot/assets/crag/quickdraw-hd.png  2 frames of 12 x 22: a bolt hanger, a
      bright sling and two carabiners; the second frame has the rope through
      the bottom one (clipped)
  godot/assets/crag/crimp-hd.png      16 x 16: two small chalked edges
  godot/assets/crag/jug-hd.png        18 x 11: a big incut hold, chalk on the
      lip, deep shadow under it
  godot/assets/crag/anchor-hd.png     18 x 16: two bolts, chains, a ring

    python3 tools/art/crag_hd.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "assets" / "crag"
SCALE, SS = 4, 2
K = SCALE * SS
LINE = (30, 22, 26, 255)
O = 0.5  # outline, world px


def c(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


STEEL = (c("#f2f4f6"), c("#c3c9cf"), c("#868e96"))
SLING = (c("#4aa3ff"), c("#2f74c8"))
ROPE = (c("#ff8a4c"), c("#e0582a"), c("#a8381a"))
STONE = (c("#d9a874"), c("#b98458"), c("#86593a"), c("#4a2c1e"))
CHALK = c("#fbf8f2")


class Pen:
    def __init__(self, w, h):
        self.im = Image.new("RGBA", (int(w * K), int(h * K)), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.w, self.h = w, h

    def p(self, x, y):
        return (x * K, y * K)

    def ellipse(self, x0, y0, x1, y1, fill, outline=True, ring=0.0):
        if outline:
            self.d.ellipse([*self.p(x0 - O, y0 - O), *self.p(x1 + O, y1 + O)], fill=LINE)
        self.d.ellipse([*self.p(x0, y0), *self.p(x1, y1)], fill=fill)
        if ring:
            self.d.ellipse([*self.p(x0 + ring, y0 + ring), *self.p(x1 - ring, y1 - ring)], fill=LINE)
            self.d.ellipse([*self.p(x0 + ring + O, y0 + ring + O), *self.p(x1 - ring - O, y1 - ring - O)], fill=(0, 0, 0, 0))

    def ring(self, x0, y0, x1, y1, width, fill, shade):
        """A carabiner-like loop: outline, metal, inner hole."""
        self.d.ellipse([*self.p(x0 - O, y0 - O), *self.p(x1 + O, y1 + O)], fill=LINE)
        self.d.ellipse([*self.p(x0, y0), *self.p(x1, y1)], fill=fill)
        self.d.ellipse([*self.p(x0 + width * 0.55, y0 + width * 0.55), *self.p(x1, y1)], fill=shade)
        self.d.ellipse([*self.p(x0 + width, y0 + width), *self.p(x1 - width, y1 - width)], fill=LINE)
        self.d.ellipse([*self.p(x0 + width + O, y0 + width + O), *self.p(x1 - width - O, y1 - width - O)], fill=(0, 0, 0, 0))

    def rrect(self, x0, y0, x1, y1, r, fill, outline=True):
        if outline:
            self.d.rounded_rectangle([*self.p(x0 - O, y0 - O), *self.p(x1 + O, y1 + O)], radius=(r + O) * K, fill=LINE)
        self.d.rounded_rectangle([*self.p(x0, y0), *self.p(x1, y1)], radius=r * K, fill=fill)

    def line(self, pts, width, fill, outline=True):
        q = [self.p(x, y) for x, y in pts]
        if outline:
            self.d.line(q, fill=LINE, width=int((width + 2 * O) * K), joint="curve")
        self.d.line(q, fill=fill, width=int(width * K), joint="curve")

    def poly(self, pts, fill, outline=True):
        if outline:
            # A fat outline: the same polygon stroked.
            q = [self.p(x, y) for x, y in pts]
            self.d.line(q + q[:1], fill=LINE, width=int(O * 2 * K), joint="curve")
        self.d.polygon([self.p(x, y) for x, y in pts], fill=fill)

    def done(self):
        return self.im.resize((int(self.w * SCALE), int(self.h * SCALE)), Image.LANCZOS)


def quickdraw(clipped):
    pen = Pen(12, 22)
    # Bolt hanger: a steel plate on the rock with the bolt head.
    pen.ellipse(3.2, 0.8, 8.8, 7.0, STEEL[1])
    pen.ellipse(3.8, 1.2, 7.6, 4.6, STEEL[0], outline=False)
    pen.ellipse(5.0, 3.6, 7.0, 5.6, LINE, outline=False)
    pen.ellipse(5.3, 1.6, 6.6, 2.9, STEEL[2])
    # Top carabiner through the hanger.
    pen.ring(3.6, 4.6, 8.4, 10.6, 1.0, STEEL[1], STEEL[2])
    # The sling (dogbone), bright so the bolt is seen from below.
    pen.rrect(4.4, 9.6, 7.6, 15.4, 1.4, SLING[0])
    pen.rrect(5.5, 10.2, 7.0, 14.8, 0.7, SLING[1], outline=False)
    pen.line([(4.6, 12.4), (7.4, 12.4)], 0.4, c("#d9ecff"), outline=False)
    # Bottom carabiner, the one the rope goes through.
    pen.ring(3.2, 14.2, 8.8, 21.2, 1.1, STEEL[1], STEEL[2])
    if clipped:
        pen.line([(0.6, 19.6), (11.4, 17.0)], 1.8, ROPE[1])
        pen.line([(0.8, 19.1), (11.2, 16.5)], 0.6, ROPE[0], outline=False)
    else:
        # Gate: a little gap and a highlight, waiting for the rope.
        pen.line([(8.4, 16.0), (8.4, 19.4)], 0.5, STEEL[0], outline=False)
    return pen.done()


def crimp():
    pen = Pen(16, 16)
    for x, y, w in ((2.4, 4.4, 5.2), (9.0, 11.0, 4.4)):
        # The edge's shadow, then the lit edge, then chalk on top.
        pen.rrect(x, y, x + w, y + 1.9, 0.9, STONE[3])
        pen.rrect(x + 0.2, y - 0.5, x + w - 0.2, y + 0.9, 0.7, STONE[0], outline=False)
        for k in range(int(w)):
            pen.ellipse(x + 0.6 + k * 0.95, y - 1.4, x + 1.3 + k * 0.95, y - 0.7, c("#fbf8f2", 200), outline=False)
    return pen.done()


def jug():
    pen = Pen(18, 11)
    # The hold: a lumpy block of stone standing off the wall, incut under
    # its lip, lit from the upper left.
    pen.poly([(1.0, 7.0), (1.8, 3.6), (4.2, 1.4), (8.8, 0.8), (13.4, 1.2), (16.4, 3.2), (17.0, 6.6), (15.2, 9.8), (9.6, 10.2), (3.0, 9.6)], STONE[1])
    pen.poly([(2.2, 5.6), (3.0, 3.4), (5.0, 2.0), (9.0, 1.6), (12.8, 2.0), (15.0, 3.6), (12.0, 4.2), (6.0, 4.6)], STONE[0], outline=False)
    pen.poly([(15.6, 4.0), (16.2, 6.6), (14.8, 9.2), (13.0, 8.8)], STONE[2], outline=False)
    # The incut: a dark pocket under the lip, where the fingers go.
    pen.poly([(4.0, 6.0), (14.0, 5.6), (13.2, 8.4), (5.0, 8.6)], STONE[3], outline=False)
    pen.poly([(5.4, 7.4), (12.6, 7.0), (12.0, 8.2), (6.0, 8.3)], c("#26160e"), outline=False)
    # Chalk: dabs along the lip, not a stripe.
    for x, y in ((4.6, 4.6), (6.6, 4.3), (8.4, 4.5), (10.2, 4.2), (12.0, 4.5), (7.4, 5.2), (11.0, 5.0)):
        pen.ellipse(x, y, x + 1.3, y + 0.9, c("#fbf8f2", 220), outline=False)
    return pen.done()


def anchor():
    pen = Pen(18, 16)
    for x in (2.0, 11.0):
        pen.ellipse(x, 0.8, x + 5.0, 5.8, STEEL[1])
        pen.ellipse(x + 1.6, 2.4, x + 3.4, 4.2, LINE, outline=False)
    # Chains down to a ring.
    for x0 in (4.5, 13.5):
        y = 5.2
        for k in range(3):
            pen.ring(x0 - 1.0 + (4.5 - x0) * 0.25 * k / 2, y, x0 + 1.0 + (4.5 - x0) * 0.25 * k / 2, y + 2.4, 0.5, STEEL[1], STEEL[2])
            y += 1.8
    pen.ring(6.0, 10.0, 12.0, 15.4, 1.1, STEEL[0], STEEL[2])
    return pen.done()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (12 * SCALE * 2, 22 * SCALE), (0, 0, 0, 0))
    sheet.paste(quickdraw(False), (0, 0))
    sheet.paste(quickdraw(True), (12 * SCALE, 0))
    sheet.save(OUT / "quickdraw-hd.png")
    crimp().save(OUT / "crimp-hd.png")
    jug().save(OUT / "jug-hd.png")
    anchor().save(OUT / "anchor-hd.png")
    print("wrote quickdraw-hd, crimp-hd, jug-hd, anchor-hd")


if __name__ == "__main__":
    main()
