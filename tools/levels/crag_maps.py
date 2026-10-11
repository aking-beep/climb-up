"""
The crag's routes: one cliff, five lines up it, easiest first. Writes
godot/modes/crag/routes/<id>.txt for the Godot Crag mode.

Legend (as the expedition maps, plus the crag's own):
  #  rock (the ground, and the ledge along the top of the cliff)
  .  air; below the ledge it is the blank wall of the cliff, unclimbable
  C  the line: rock you can climb
  k  crimps: small holds, they wear the arms out fast, keep moving
  J  a jug: a big hold to hang on and shake the arms out
  Q  a bolt with a quickdraw beside the line (clip it as you pass)
  P  where you start, at the foot of the cliff
  X  the anchor at the top: the route is done

A gap of two rows in a line is blank rock: the only way past is a dyno.

    python3 tools/levels/crag_maps.py
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "modes" / "crag" / "routes"
W = 36
WALL_X = 10  # the cliff starts here; left of it is open ground under the sky
LEDGE = 5    # the ledge along the top: rows LEDGE and LEDGE + 1


class Route:
    def __init__(self, height):
        self.h = height
        self.g = [["." for _ in range(W)] for _ in range(height)]
        for y in (height - 2, height - 1):
            for x in range(W):
                self.g[y][x] = "#"
        for y in (LEDGE, LEDGE + 1):
            for x in range(WALL_X, W):
                self.g[y][x] = "#"
        self.g[height - 3][4] = "P"

    @property
    def foot(self):
        return self.h - 3

    def fill(self, x0, x1, y0, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = ch

    def line(self, x0, y0, y1, ch="C", width=3):
        """A vertical line of holds, x0..x0+width-1, rows y0..y1."""
        self.fill(x0, x0 + width - 1, y0, y1, ch)

    def exit(self, x0, width=3):
        """The line through the ledge to the top, and the anchor beside it."""
        self.fill(x0, x0 + width - 1, LEDGE, LEDGE + 1, "C")
        self.g[LEDGE - 1][x0 + width + 2] = "X"

    def bolt(self, x, y):
        assert self.g[y][x] == ".", (x, y, self.g[y][x])
        self.g[y][x] = "Q"

    def text(self):
        return "\n".join("".join(r) for r in self.g) + "\n"


def warm_up():
    """Grade 4. Straight up good rock, a jug halfway to shake out."""
    r = Route(24)
    r.line(14, LEDGE, r.foot)
    r.line(14, 12, 13, "J")
    r.exit(14)
    for y in (r.foot - 3, 14, 8):
        r.bolt(17, y)
    return r


def sundown():
    """Grade 5b. Up, a long traverse right (a jug, then crimps), then up."""
    r = Route(28)
    r.line(12, 16, r.foot)
    r.fill(12, 26, 15, 16, "C")
    r.fill(14, 15, 15, 16, "J")
    r.fill(18, 20, 15, 16, "k")
    r.line(24, LEDGE, 16)
    r.line(24, 13, 14, "J")
    r.exit(24)
    r.bolt(15, r.foot - 3)
    r.bolt(15, 18)
    r.bolt(21, 13)
    r.bolt(27, 7)
    return r


def the_pinch():
    """Grade 6a. A jug to rest on, then seven rows of crimps: don't stop."""
    r = Route(30)
    r.line(15, LEDGE, r.foot)
    r.line(15, 15, 16, "J")
    r.line(15, 8, 14, "k")
    r.exit(15)
    for y in (r.foot - 3, 19, 13, 7):
        r.bolt(18, y)
    return r


def leap_of_faith():
    """Grade 6b. A jug, then blank rock: dyno to the holds above."""
    r = Route(30)
    r.line(15, 16, r.foot)
    r.line(15, 14, 15, "J")
    # 12-13: blank. The upper line starts at 11.
    r.line(15, LEDGE, 11)
    r.line(15, 8, 10, "k")
    r.exit(15)
    for y in (r.foot - 4, 16, 8):
        r.bolt(18, y)
    return r


def lions_roof():
    """Grade 6c. Crimps low, a jug, a traverse on crimps, a jug, a dyno,
    crimps to the top."""
    r = Route(34)
    r.line(12, 22, r.foot)
    r.line(12, 23, 25, "k")
    r.fill(12, 23, 20, 21, "C")
    r.fill(12, 13, 20, 21, "J")
    r.fill(16, 19, 20, 21, "k")
    # The roof: rock right over your head along the traverse.
    r.fill(14, 20, 18, 18, "#")
    r.line(21, 18, 19, "J")
    # 16-17: blank. Dyno.
    r.line(21, LEDGE, 15)
    r.line(21, 9, 11, "k")
    r.exit(21)
    r.bolt(15, r.foot - 3)
    r.bolt(15, 24)
    r.bolt(24, 20)
    r.bolt(24, 9)
    return r


def thunderhead():
    """Grade 7a. Crimps, a jug, a dyno, crimps, a jug under the roof, the
    roof on crimps, a jug, a second dyno, crimps to the top."""
    r = Route(40)
    r.line(13, 27, r.foot)
    r.line(13, 30, 33, "k")
    r.line(13, 25, 26, "J")
    # 23-24: blank. Dyno one.
    r.line(13, 19, 22)
    r.line(13, 21, 22, "k")
    r.line(13, 19, 20, "J")
    r.fill(13, 24, 17, 18, "C")
    r.fill(17, 20, 17, 18, "k")
    r.fill(16, 21, 15, 15, "#")
    r.line(22, 15, 16, "J")
    r.line(22, 13, 14)
    # 11-12: blank. Dyno two.
    r.line(22, LEDGE, 10)
    r.line(22, 6, 9, "k")
    r.exit(22)
    r.bolt(16, 34)
    r.bolt(16, 28)
    r.bolt(16, 21)
    r.bolt(25, 16)
    r.bolt(25, 8)
    return r


ROUTES = {
    "warm-up": warm_up,
    "sundown": sundown,
    "the-pinch": the_pinch,
    "leap-of-faith": leap_of_faith,
    "lions-roof": lions_roof,
    "thunderhead": thunderhead,
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in ROUTES.items():
        r = build()
        path = OUT / f"{name}.txt"
        path.write_text(r.text())
        print("wrote", path, f"{W}x{r.h}")


if __name__ == "__main__":
    main()
