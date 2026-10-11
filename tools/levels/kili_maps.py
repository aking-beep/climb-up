"""
The Godot Lava Tower and summit night levels, stamped as ASCII maps with the
same legend as barranco_map.py, plus:
  m  Marco at camp (not the teammate who needs help)

Writes godot/modes/expedition/levels/kilimanjaro/<level>/<level>.txt.
Game fiction inspired by the place, not a description of the real route.

    python3 tools/levels/kili_maps.py [--preview <dir>]
"""

import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEVELS = ROOT / "godot" / "modes" / "expedition" / "levels" / "kilimanjaro"


class Map:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [["." for _ in range(w)] for _ in range(h)]

    def fill(self, x0, y0, x1, y1, ch):
        for y in range(max(0, y0), min(self.h - 1, y1) + 1):
            for x in range(max(0, x0), min(self.w - 1, x1) + 1):
                self.g[y][x] = ch

    def put(self, x, y, ch):
        self.g[y][x] = ch

    def get(self, x, y):
        return self.g[y][x]

    def slope_up_right(self, x, floor, rise):
        """A '/' ramp starting at column x on floor row `floor`, rising `rise` rows."""
        for i in range(rise):
            cx, cy = x + i, floor - 1 - i
            self.put(cx, cy, "/")
            self.fill(cx, cy + 1, cx, self.h - 1, "#")

    def slope_down_right(self, x, top, drop):
        """A '\\' ramp starting at column x just under floor row `top`, falling `drop` rows."""
        for i in range(drop):
            cx, cy = x + i, top + i
            self.fill(cx, 0, cx, cy - 1, ".")
            self.put(cx, cy, "\\")
            self.fill(cx, cy + 1, cx, self.h - 1, "#")

    def roughen(self, x0, x1, y0, y1, seed, chance=0.4):
        """Ragged rock on air edges where nobody walks."""
        rnd = random.Random(seed)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.g[y][x] == "." and rnd.random() < chance:
                    self.g[y][x] = "#"

    def text(self):
        return "\n".join("".join(row) for row in self.g) + "\n"


def lava_tower():
    """
    The warm-up. Shira 2's tents on the plateau, a walk up to the tower foot,
    a scramble band, a loose scree face, a ledge open to the plateau wind,
    a chimney to the top, and the walk down toward Barranco.
    """
    m = Map(150, 64)
    CAMP = 56  # camp floor row
    m.fill(0, CAMP, 49, 63, "#")
    m.slope_up_right(40, CAMP, 6)            # floor 50 from x 46
    m.fill(46, 50, 51, 63, "#")
    # The tower: one mass from the foot to its top, and the ground beyond.
    m.fill(52, 14, 110, 63, "#")
    m.fill(111, 24, 149, 63, "#")
    # 1. Scramble band at the foot, up to bench 1 (floor row 42).
    m.fill(52, 39, 75, 41, ".")
    m.fill(52, 42, 54, 49, "s")
    # 2. A loose scree face from the east end of bench 1 to bench 2 (floor 30).
    m.fill(52, 27, 75, 29, ".")
    m.fill(73, 30, 75, 41, "L")
    # The west end of bench 2 is open to the plateau: the windy ledge.
    m.fill(40, 0, 51, 49, ".")
    m.fill(52, 0, 54, 26, ".")
    m.put(51, 29, "#")                       # a curb at the lip
    m.fill(51, 30, 51, 33, "#")
    # 3. The chimney: from bench 2 up to the top of the tower (floor 14).
    m.fill(55, 14, 57, 29, "C")
    m.fill(55, 0, 110, 13, ".")
    # The way down: off the east side of the tower to the scree below.
    m.slope_down_right(111, 14, 10)
    m.fill(121, 0, 149, 23, ".")
    m.fill(149, 0, 149, 63, "#")
    m.fill(0, 0, 0, CAMP - 1, ".")
    # Challenge: a scree bridge across a gap in bench 1. The slabs hold a
    # walker; stop on them and they go.
    m.fill(64, 42, 67, 48, ".")
    m.fill(64, 42, 67, 42, "c")
    # Challenge: stones come down the chimney. A niche halfway up to shelter.
    m.fill(58, 20, 59, 22, ".")
    m.put(56, 6, "r")
    # Secret: a ledge over the scree beyond the tower, up a short face.
    m.fill(128, 16, 130, 23, "C")
    m.fill(131, 16, 134, 17, "#")
    # Exposure: bench 2 west of the chimney.
    for x in range(52, 55):
        m.put(x, 29, "E")
    for x in range(58, 64):
        m.put(x, 29, "E")
    # Camp, people, cairns, signs.
    f = CAMP - 1
    m.put(3, f, "g")
    m.put(6, f, "T")
    m.put(10, f, "F")
    m.put(13, f, "T")
    m.put(17, f, "m")
    m.put(20, f, "l")
    m.put(25, f, "P")
    m.put(30, f, "S")      # sign 0: Shira 2
    m.put(35, f, "o")
    m.put(49, 49, "K")     # cairn 1, the tower foot
    m.put(47, 49, "S")     # sign 1: scree
    m.put(60, 41, "K")     # cairn 2, bench 1
    m.put(70, 29, "K")     # cairn 3, bench 2
    m.put(68, 29, "R")
    m.put(65, 29, "S")     # sign 2: wind
    m.put(62, 13, "K")     # cairn 4, top of the tower
    m.put(64, 13, "S")     # sign 3: the top
    m.put(72, 13, "V")
    m.put(90, 13, "g")
    m.put(126, 23, "o")
    m.put(145, 23, "X")
    # The walk: a boulder to hop and a stream cut to jump on the way out of
    # camp, a stone that rolls down the approach, a boulder on the windy
    # bench, and a crack and a boulder on the way down.
    m.put(33, CAMP - 1, "#")
    m.fill(37, CAMP, 38, 63, ".")
    m.put(50, 49, "b")
    m.put(62, 29, "#")
    m.fill(137, 24, 138, 30, ".")
    m.put(141, 23, "#")
    # Across the top of the tower: a boulder, a crack, a stone rolling at
    # you from the far edge; and a boulder on the scree below.
    m.put(76, 13, "#")
    m.fill(90, 14, 91, 20, ".")
    m.put(106, 13, "b")
    m.put(124, 23, "#")
    # Water, and the lost gear: out on the windy lip, in the chimney's
    # niche, and on the ledge beyond the tower.
    m.put(70, 41, "w")
    m.put(52, 29, "*")
    m.put(59, 22, "*")
    m.put(133, 15, "*")
    return m


def summit_night():
    """
    The last and hardest climb. Barafu's tents at the bottom left; frozen
    switchbacks of scree and rock steps, each with a cairn; Jun on the fourth
    with a rest stone; the crater rim, open to the wind; a last rock step
    to Stella Point at first light.
    """
    m = Map(132, 92)
    m.fill(0, 0, 131, 91, "#")
    # Benches: floor rows, bottom to top. Each is a shelf of rock three
    # rows thick with six rows of open air above it, so the switchbacks
    # read as ledges on the flank, not tunnels.
    floors = [86, 77, 68, 59, 50, 41]
    x0, x1 = 14, 104
    for f in floors:
        m.fill(x0, f - 6, x1, f - 1, ".")
    # Camp at Barafu: a wider shelf at the bottom left.
    m.fill(1, floors[0] - 6, x0, floors[0] - 1, ".")
    # Steps between benches alternate sides: loose scree, rock, scramble.
    kinds = ["L", "C", "s", "L", "C"]
    for i, kind in enumerate(kinds):
        lo, hi = floors[i], floors[i + 1]
        # Right side for even steps, left for odd.
        cx = x1 - 2 if i % 2 == 0 else x0
        m.fill(cx, hi, cx + 2, lo - 1, kind)
    # The crater rim: open sky above the top bench's roof, reached by a
    # last loose step on the left. A wall of the crater edge closes it west.
    RIM = 32
    m.fill(0, 0, 131, RIM - 1, ".")
    m.fill(x0, RIM, x0 + 2, floors[-1] - 1, "L")
    m.fill(0, RIM - 3, x0 - 1, RIM - 1, "#")
    # The rim runs east along the top and is exposed to the wind.
    for x in range(40, 92):
        m.put(x, RIM - 1, "E")
    # Stella Point: a last rock step at the east end of the rim.
    STELLA = RIM - 8
    m.fill(108, STELLA, 131, RIM - 1, "#")
    m.fill(108, STELLA, 110, RIM - 1, "C")
    m.fill(131, 0, 131, 91, "#")
    # Challenge: ice on the switchbacks. On the fourth bench it runs up to a
    # crevasse, crossed on a band of rock above it.
    for x in range(30, 91):
        m.put(x, floors[1], "i")
    for x in range(84, 101):
        m.put(x, floors[3], "i")
    m.fill(80, floors[3], 81, floors[3] + 2, ".")
    m.fill(78, floors[3] - 4, 83, floors[3] - 1, "C")
    # Challenge: stones down the last rock step and the rim step.
    m.put(x1 - 1, floors[5] - 5, "r")
    m.put(x0 + 1, RIM - 6, "r")
    # Challenge: cracked slabs on the rim, over a hole to the bench below.
    m.fill(60, RIM, 61, RIM + 2, ".")
    m.fill(60, RIM, 61, RIM, "c")
    # Secrets: a pocket off each end of two benches, and a ledge above the rim.
    m.fill(9, floors[3] - 4, 13, floors[3] - 1, ".")
    m.fill(x1 + 1, floors[2] - 4, x1 + 4, floors[2] - 1, ".")
    m.fill(30, RIM - 7, 32, RIM - 1, "C")
    m.fill(33, RIM - 7, 36, RIM - 6, "#")
    m.put(10, floors[3] - 1, "*")
    m.put(x1 + 3, floors[2] - 1, "*")
    m.put(35, RIM - 8, "*")
    m.put(66, floors[3] - 1, "w")
    # The walk between the steps: gaps to jump, boulders and an ice block to
    # hop, stones rolling along two benches.
    m.fill(50, floors[0], 51, 91, ".")
    m.put(70, floors[0] - 1, "#")
    m.put(60, floors[1] - 1, "i")
    m.put(95, floors[2] - 1, "b")
    m.fill(55, floors[4], 56, floors[4] + 2, ".")
    m.put(26, floors[5] - 1, "d")
    m.put(75, RIM - 1, "#")
    # Something every twenty steps or so on every bench.
    f = floors
    m.put(30, f[0] - 1, "#")
    m.fill(86, f[0], 87, 91, ".")
    m.fill(86, f[0], 87, f[0], "c")
    m.fill(80, f[1], 81, f[1] + 2, ".")
    m.put(40, f[1] - 1, "i")
    m.put(30, f[1] - 1, "d")
    m.put(35, f[2] - 1, "#")
    m.fill(50, f[2], 51, f[2] + 2, ".")
    m.fill(50, f[2], 51, f[2], "c")
    m.put(40, f[3] - 1, "#")
    m.fill(28, f[3], 29, f[3] + 2, ".")
    m.put(30, f[4] - 1, "#")
    m.put(43, f[4] - 1, "#")
    m.fill(75, f[4], 76, f[4] + 2, ".")
    m.fill(75, f[4], 76, f[4], "c")
    m.put(90, f[4] - 1, "b")
    m.fill(70, f[5], 71, f[5] + 2, ".")
    m.put(45, f[5] - 1, "#")
    m.fill(35, RIM, 36, RIM + 2, ".")
    m.put(x0 + 10, RIM - 1, "w")
    # Camp, people, cairns, signs.
    f0 = floors[0] - 1
    m.put(2, f0, "T")
    m.put(5, f0, "F")
    m.put(8, f0, "l")
    m.put(10, f0, "m")
    m.put(12, f0, "P")
    m.put(17, f0, "S")       # sign 0: Barafu
    m.put(22, f0, "T")
    # A cairn where each step tops out, on the bench above it.
    for i in range(len(kinds)):
        f = floors[i + 1] - 1
        m.put(x1 - 6 if i % 2 == 0 else x0 + 5, f, "K")
    m.put(x0 + 8, floors[1] - 1, "S")        # sign 1: cold
    # Jun on the fourth bench, by a rest stone, halfway along.
    m.put(60, floors[3] - 1, "M")
    m.put(56, floors[3] - 1, "R")
    m.put(x1 - 6, floors[4] - 1, "R")
    m.put(x0 + 5, RIM - 1, "K")              # cairn on the rim
    m.put(x0 + 7, RIM - 1, "S")              # sign 2: the rim
    m.put(116, STELLA - 1, "K")
    m.put(118, STELLA - 1, "S")              # sign 3: Stella Point
    m.put(122, STELLA - 1, "V")
    m.put(128, STELLA - 1, "X")
    return m


def preview(m, path):
    from PIL import Image
    colours = {
        "#": (70, 60, 52), "/": (90, 78, 66), "\\": (90, 78, 66), "C": (140, 120, 100), "L": (170, 140, 110),
        "s": (150, 130, 110), "E": (200, 120, 120), ".": (150, 180, 205), "K": (240, 220, 80), "R": (90, 160, 90),
        "P": (60, 200, 60), "X": (220, 60, 60), "M": (230, 110, 50), "S": (200, 160, 90),
        "i": (200, 235, 255), "c": (120, 60, 160), "r": (255, 0, 0), "w": (0, 90, 255), "*": (255, 255, 0),
        "b": (255, 120, 0), "d": (255, 120, 0),
    }
    img = Image.new("RGB", (m.w, m.h))
    px = img.load()
    for y in range(m.h):
        for x in range(m.w):
            px[x, y] = colours.get(m.g[y][x], (255, 255, 255))
    img.resize((m.w * 6, m.h * 6), Image.NEAREST).save(path)


def main():
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from flowers import sprinkle
    for name, build in (("lava_tower", lava_tower), ("summit_night", summit_night)):
        m = build()
        print(name, "everlastings:", sprinkle(m.g, spacing=9 if name == "summit_night" else 5))
        out = LEVELS / name / f"{name}.txt"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(m.text())
        print("wrote", out, f"{m.w}x{m.h}")
        if "--preview" in sys.argv:
            d = Path(sys.argv[sys.argv.index("--preview") + 1])
            d.mkdir(parents=True, exist_ok=True)
            preview(m, d / f"{name}.png")


if __name__ == "__main__":
    main()
