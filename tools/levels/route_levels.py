"""
The Kilimanjaro climbs: each route goes its own way up the mountain, so
each played climb is a different place on each route (Places in the game,
godot/modes/expedition/places.gd):

  route              first climb          middle climb      summit night
  lemosho (easy)     Shira Cathedral      Karanga Valley    Stella Point
  machame (medium)   Lava Tower           Barranco Wall     Southern Icefields
  umbwe (hard)       Umbwe Ridge          Arrow Glacier     Western Breach

plus a way down for each route (sunshine, cloud, storm). Every place is laid
out in the open, left to right along the mountainside, so its own sky,
skyline and weather show behind it: ramps of scree, rock steps to climb,
steps to climb down, streams and crevasses to jump, a band to traverse,
ice, mud, cracked slabs, windy ledges, stonefall.

What the climber finds is never on the path. Gear sits on a ledge off the
line, up a short wall you climb for it and climb back down; the two
artifacts sit higher, on side walls under stonefall or out in the wind.

The route also sets how big the stamina bar is (the long way's full bar,
half on the faster way, a quarter on the fastest: Trek.bar_factor), so no
wall is taller than that route's bar can climb (FACE_MAX), and the hard
route has many short walls, more stonefall and more in the way.

For each climb and route this writes

  godot/modes/expedition/levels/kilimanjaro/<climb>/<climb>_<route>.txt
  godot/modes/expedition/levels/kilimanjaro/<climb>/<climb>_<route>.json

Legend (one character per 16 px tile; core/world/terrain.gd reads it):
  #  rock (solid)              /  slope rising right    \\  slope rising left
  C  climbable face            L  loose scree face      s  scramble boulders
  E  exposed ground (wind)     R  rest stone            K  cairn (checkpoint)
  i  ice (or mud)              c  cracked slab          r  stonefall chute
  b / d  a stone rolls left / right from here           w  a drink
  *  lost gear                 n  thistle   a  siafu    v  raven
  P  start   X  exit   M  the teammate who needs help
  l Lena  j Jun  m Marco  p porter  S sign  T tent  F fire  V vista
  g groundsel  o lobelia       .  air

The JSON is what the map alone cannot say: the cairns and signs in the
order you reach them, where each piece of gear (in the spec's order) and
each artifact lies, the teammate, and the line a climber takes (a script
the level tests' bot follows: tests/climb_bot.gd follow()), including the
detours up to the finds.

    python3 tools/levels/route_levels.py [--preview <dir>]

Game fiction inspired by the places, not a description of the real routes.
"""

import json
import random
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gauntlet import gauntlet, wildlife  # noqa: E402

ROOT = HERE.parents[1]
LEVELS = ROOT / "godot" / "modes" / "expedition" / "levels" / "kilimanjaro"
ROUTES = ("lemosho", "machame", "umbwe")
SOLID = set("#/\\ic")
MARKERS = set("PXMljmpSTFgoVKRrw*bdnav")
SKY = 16          # rows of sky over the highest ground
DEEP = 10         # rows of rock under the lowest ground
# The tallest wall each route's bar can climb (rows of face; loose scree
# costs a third more, so it counts for more). The long way's full bar, the
# faster way's half, the fastest way's quarter (Trek.bar_factor).
FACE_MAX = {"lemosho": 9, "machame": 8, "umbwe": 5.5}
LOOSE = 1.35


class Course:
    def __init__(self, w, h, seed):
        self.w, self.h = w, h
        self.g = [["." for _ in range(w)] for _ in range(h)]
        self.rnd = random.Random(seed)
        self.script = []
        self.cairns = []          # in the order you reach them
        self.signs = []
        self.gear = {}            # kind -> cell
        self.artifacts = []       # cells, in the order you reach them
        self.path = []            # standing cells along the line, in order
        self.mate = None
        self.niches = []
        self.clear_spans = []      # (x0, x1, row) kept free of the gauntlet

    def fill(self, x0, y0, x1, y1, ch):
        for y in range(max(0, y0), min(self.h - 1, y1) + 1):
            for x in range(max(0, x0), min(self.w - 1, x1) + 1):
                self.g[y][x] = ch

    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        return "#"

    def say(self, *action):
        self.script.append(list(action))

    def text(self):
        return "\n".join("".join(r) for r in self.g) + "\n"


class Line:
    """A cursor walking the mountainside left to right: x is the next
    column, y the row of the ground under it (you stand on row y - 1)."""

    def __init__(self, c, route, x, y):
        self.c, self.route = c, route
        self.x, self.y = x, y
        self.min_y = self.max_y = y

    # --- ground ------------------------------------------------------------
    def _column(self, x, top):
        self.c.fill(x, top, x, self.c.h - 1, "#")

    def _track(self):
        self.min_y = min(self.min_y, self.y)
        self.max_y = max(self.max_y, self.y)

    def walk(self, n, floor="#", stand="."):
        c = self.c
        for k in range(n):
            x = self.x + k
            self._column(x, self.y)
            if floor != "#":
                c.put(x, self.y, floor)
            if stand != ".":
                c.put(x, self.y - 1, stand)
            c.path.append((x, self.y - 1))
        self.x += n

    def up(self, n):
        """A ramp of scree rising right: n columns, n rows."""
        for k in range(n):
            x = self.x + k
            self.c.put(x, self.y - 1 - k, "/")
            self._column(x, self.y - k)
            self.c.path.append((x, self.y - 2 - k))
        self.x += n
        self.y -= n
        self._track()

    def down(self, n):
        """A ramp falling right."""
        for k in range(n):
            x = self.x + k
            self.c.put(x, self.y + k, "\\")
            self._column(x, self.y + k + 1)
            self.c.path.append((x, self.y + k - 1))
        self.x += n
        self.y += n
        self._track()

    @staticmethod
    def need(h, kind="C"):
        """Stamina a wall of h rows costs to climb, with room for the cold
        and the thin air: the line rests first only if it has less."""
        return round(h * 16 / 34 * 6.0 * (LOOSE if kind == "L" else 1.0) * 1.45 + 3, 1)

    def _fits(self, h, kind):
        rows = h * (LOOSE if kind == "L" else 1.0)
        assert rows <= FACE_MAX[self.route] + 0.01, (self.route, "a wall taller than the bar", h, kind)

    def face(self, h, kind="C", chute=False, niche=False, rest=True):
        """A rock step up: a three-wide face from the ground to the ground
        h rows higher, climbed and pulled over to the right."""
        self._fits(h, kind)
        c, x, lo = self.c, self.x, self.y
        hi = lo - h
        for k in range(3):
            self._column(x + k, lo)
        c.fill(x, hi, x + 2, lo - 1, kind)
        self._column(x + 3, hi)
        if chute:
            # Stones down the left of the face (and the ground before it):
            # its right-hand column is out of their line, for whoever reads
            # the grit.
            c.put(x, hi - 5, "r")
        nich = None
        if niche:
            # A niche cut into the rock beside the face, halfway up: a place
            # to rest out of the stones on a tall one (cut once the rock
            # beside it is laid: Course.niches).
            nf = (lo + hi) // 2
            c.niches.append((x + 3, nf))
            nich = {"row": nf, "x": x + 3.6, "back": x + 2.4}
        if rest:
            c.say("walk", x - 2.5)
            c.say("rest", 0.98, self.need(h, kind))
        # Under a chute, the line is the face's right-hand column, out of the
        # stones' line.
        c.say("climb", {"x": x + (2.5 if chute else 1.5), "dir": 1, "row": hi, "lean": 1, "chute": chute, "niche": nich, "kind": kind})
        self.x += 3
        self.y = hi
        self._track()

    def step(self, h, rest=True):
        """A rock step down: stand at its edge and climb down."""
        c, x, y = self.c, self.x, self.y
        for k in range(3):
            self._column(x + k, y)
        c.fill(x, y, x + 2, y + h - 1, "C")
        self._column(x + 3, y + h)
        # Stand a step back from the lip: from right at its edge there is no
        # stepping down onto the face.
        c.say("walk", x - 1.5)
        if rest:
            c.say("rest", 0.95, self.need(h))
        c.say("down", {"dir": 1, "row": y + h})
        self.x += 3
        self.y += h
        self._track()

    def gap(self, w=2, depth=5):
        """A stream bed or a crack to jump: w wide, depth deep, floored;
        depth None is a hole open to the bottom of the map (fall in and the
        climb starts again)."""
        for k in range(w):
            if depth is not None:
                self._column(self.x + k, self.y + depth)
        self.x += w

    def crevasse(self):
        """A crevasse two wide and six deep, a band of rock over it to cross
        on (a fall in is a fall)."""
        c, x, y = self.c, self.x, self.y
        self.walk(3)
        for k in range(2):
            self._column(x + 3 + k, y + 6)
        self.x += 2
        self.walk(3)
        c.fill(x + 1, y - 4, x + 6, y - 1, "C")

    def traverse(self, n):
        """A band of rock along a wall over a void (Kissing Rock): grab it
        and move along it; a fall lands in the void, a slip."""
        c, x, y = self.c, self.x, self.y
        self.walk(1)
        x0 = self.x
        for k in range(n):
            self._column(x0 + k, y + 5)
        self.x += n
        self.walk(2)
        c.fill(x0 - 1, y - 4, x0 + n, y - 1, "C")
        c.fill(x0 - 1, y - 8, x0 + n, y - 5, "#")
        c.say("walk", x0 - 0.5)
        c.say("rest", 0.98, self.need(n + 4))
        c.say("traverse", {"to": x0 + n + 1.0, "dir": 1, "row": y - 4})

    def slabs(self):
        """Cracked slabs over a pit: keep walking."""
        c, x, y = self.c, self.x, self.y
        self.walk(1)
        for k in range(2):
            self._column(self.x + k, y + 5)
            c.put(self.x + k, y, "c")
            c.path.append((self.x + k, y - 1))
        self.x += 2
        self.walk(1)

    def rocks(self, n):
        """A stretch with boulders to hop every five tiles (the walks the
        gauntlet leaves alone: down from a top, out to the exit)."""
        self.walk(n)
        for k in range(3, n - 2, 5):
            self.c.put(self.x - n + k, self.y - 1, "#")

    def ice(self, n, clear=False):
        """Ice underfoot (mud in the forest). A clear run keeps nothing on it:
        a long slide, with nothing to hop."""
        if clear:
            self.c.clear_spans.append((self.x, self.x + n - 1, self.y - 1))
        self.walk(n, floor="i")

    def wind(self, n):
        """Exposed ground the wind crosses, then a few steps of lee (never a
        rest, a wall or a find straight off the wind)."""
        self.walk(n, stand="E")
        self.walk(3)

    def roller(self, n):
        """A flat stretch with a stone that rolls down it at you."""
        self.walk(n)
        self.c.put(self.x - 2, self.y - 1, "b")

    # --- markers -------------------------------------------------------------
    def mark(self, ch, dx=0):
        self.c.put(self.x + dx, self.y - 1, ch)

    def breather(self, dx=1):
        """A stone to sit by in the lee, and the line sits there: a rest on
        a long walk."""
        self.mark("R", dx)
        self.c.say("walk", self.x + dx + 0.5)
        self.c.say("rest", 0.98)

    def cairn(self, dx=1):
        x = self.x + dx
        self.c.put(x, self.y - 1, "K")
        self.c.cairns.append([x, self.y - 1])

    def sign(self, dx=1):
        x = self.x + dx
        self.c.put(x, self.y - 1, "S")
        self.c.signs.append([x, self.y - 1])

    def mate(self):
        """The teammate who needs help, on the path, with a cairn before."""
        c = self.c
        self.walk(2)
        self.cairn(-1)
        self.walk(5)
        mx = self.x
        c.put(mx, self.y - 1, "M")
        c.mate = {"cell": [mx, self.y - 1], "passDir": 1}
        c.say("walk", mx - 6.5)
        c.say("mate", {"dir": 1, "choice": "help"})
        c.say("rest", 0.98)
        self.walk(6)

    def spur(self, h, find, chute=False, windy=False, raven=False):
        """Something worth having, off the line: a ledge h rows over the
        path, reached by a two-wide wall you climb and climb back down.
        The path goes on under the ledge. `find` is "gear:<kind>",
        "artifact" or "water"."""
        self._fits(h, "C")
        assert h >= 4, "room to walk under the ledge"
        c, x, y = self.c, self.x, self.y
        s = y - h
        self.walk(8)
        c.fill(x, s, x + 1, y - 1, "C")
        c.fill(x + 2, s, x + 6, s, "#")
        cell = (x + 4, s - 1)
        if find.startswith("gear:"):
            c.gear[find[5:]] = cell
            c.put(cell[0], cell[1], "*")
        elif find == "water":
            c.put(cell[0], cell[1], "w")
        else:
            c.artifacts.append(list(cell))
        if windy:
            # The wind crosses the ledge; its first step, at the top of the
            # wall, is in the lee, a place to rest before climbing down.
            for xx in (x + 3, x + 5, x + 6):
                c.put(xx, s - 1, "E")
        if chute:
            c.put(x + 1, s - 6, "r")
        if raven:
            c.put(x + 4, s - 4, "v")
        c.say("walk", x - 2.5)
        # Up and back down: twice the wall.
        c.say("rest", 0.98, self.need(h))
        c.say("fetch", {"x": x + 1.0, "row": s, "item": x + 4.5, "back": x + 2.3, "floor": y, "chute": chute,
                        "down": self.need(h)})
        if find.startswith("gear:"):
            c.say("use", find[5:])

    def start(self, width, people, sign_at=None):
        """Camp: flat ground with the party, the start (P) and a sign."""
        self.walk(width)
        for dx, ch in people:
            self.c.put(self.x - width + dx, self.y - 1, ch)
        if sign_at is not None:
            x = self.x - width + sign_at
            self.c.put(x, self.y - 1, "S")
            self.c.signs.append([x, self.y - 1])

    def finish(self, n, summit=False):
        """The last stretch and the exit post (on a summit, the top)."""
        self.walk(n)
        self.c.put(self.x - 4, self.y - 1, "X")
        self._column(self.x, 0)
        self.x += 1
        self.c.say("finish", 1)


# --- The places ----------------------------------------------------------------
# Each is a list of pieces for Line, read left to right. Signs count must
# match the level spec's signs for the climb (4, 5, 4, 4).

def shira_cathedral(L):
    """Easy. Moorland, a buttress of old basalt, a windy rim, the way back
    down. Big bar, short walls, few stones."""
    L.start(30, [(3, "T"), (7, "F"), (10, "T"), (14, "m"), (17, "l"), (22, "P")], sign_at=26)
    L.walk(3); L.gap(2, depth=None); L.walk(4)
    L.spur(4, "gear:poles")
    L.walk(10); L.up(4); L.walk(12)
    L.cairn(); L.sign(4); L.walk(10)
    L.face(4, "s")
    L.walk(6); L.cairn(); L.walk(6)
    L.spur(5, "gear:gloves")
    L.walk(10); L.mark("R", 2); L.walk(6)
    L.face(6, "C")
    L.walk(4); L.cairn(); L.walk(4); L.sign(2); L.walk(4)
    L.wind(8)
    L.spur(5, "gear:shell", windy=True)
    L.walk(8); L.up(3); L.walk(10)
    L.spur(6, "gear:rope")
    L.walk(8); L.mark("w", 2); L.walk(8)
    L.spur(7, "artifact", windy=True)
    L.walk(10)
    L.face(6, "C", chute=True)
    L.walk(4); L.cairn(); L.walk(6)
    L.spur(5, "gear:helmet")
    L.walk(10)
    L.face(5, "L")
    L.walk(5); L.sign(1); L.mark("V", 4); L.walk(10)
    L.spur(8, "artifact", chute=True)
    L.rocks(14); L.cairn(); L.walk(2); L.rocks(7)
    L.down(6); L.rocks(10); L.down(5); L.rocks(8)
    L.finish(9)
    return {"every": 9, "kinds": ("hop", "plant", "hop", "raven"), "wildlife": True}


def lava_tower(L):
    """Medium. Red scree and the tower: rolling stones, loose faces, a
    chimney under stonefall, slabs, the plateau wind, a niche."""
    L.start(30, [(3, "g"), (6, "T"), (10, "F"), (13, "T"), (17, "m"), (20, "l"), (25, "P")], sign_at=28)
    L.walk(8)
    L.spur(4, "gear:rope")
    L.walk(8); L.up(5); L.roller(16)
    L.cairn(); L.sign(4); L.walk(8)
    L.face(5, "s")
    L.walk(6); L.cairn(); L.walk(4)
    L.spur(6, "gear:gloves")
    L.walk(8); L.slabs(); L.walk(8)
    L.face(5, "L")
    L.walk(4); L.cairn(); L.walk(4); L.sign(3); L.walk(4)
    L.wind(9)
    L.spur(6, "gear:shell", windy=True)
    L.walk(8); L.up(4); L.walk(8)
    L.spur(7, "artifact", windy=True)
    L.walk(10); L.mark("R", 2); L.walk(6)
    L.face(8, "C", chute=True, niche=True)
    L.walk(4); L.cairn(); L.walk(4)
    L.spur(6, "gear:helmet")
    L.walk(8); L.slabs(); L.walk(6)
    L.face(5, "L")
    L.walk(5); L.sign(1); L.mark("V", 4); L.walk(8)
    L.spur(8, "artifact", chute=True)
    L.walk(8); L.roller(16); L.cairn(); L.walk(4)
    L.spur(4, "gear:poles")
    L.walk(6)
    L.down(7); L.rocks(10); L.down(6); L.rocks(8)
    L.finish(14)
    return {"every": 6, "kinds": ("hop", "plant", "pit", "raven", "slabs", "ants", "ice"), "wildlife": True}


def umbwe_ridge(L):
    """Hard. Cloud forest on a knife of a ridge: many short root walls,
    mud, branches coming down, siafu and nettles everywhere, pits. A quarter
    of the bar: rest stones often."""
    L.start(26, [(3, "T"), (6, "F"), (9, "T"), (13, "m"), (16, "l"), (20, "P")], sign_at=23)
    L.walk(4); L.gap(2); L.walk(6)
    L.face(4, "s")
    L.walk(5); L.cairn(); L.walk(5)
    L.spur(4, "gear:gloves")
    L.walk(6); L.ice(5); L.walk(5)
    L.face(5, "s", chute=True)
    L.walk(3); L.mark("R", 1); L.walk(4); L.sign(1); L.walk(4)
    L.spur(5, "gear:helmet", chute=True)
    L.walk(6)
    L.face(4, "C", chute=True)
    L.walk(4); L.cairn(); L.walk(4)
    L.ice(6); L.walk(4)
    L.spur(4, "gear:poles")
    L.walk(6); L.up(3); L.walk(6)
    L.face(5, "s")
    L.walk(3); L.mark("R", 1); L.walk(5)
    L.spur(5, "artifact", chute=True)
    L.walk(6); L.gap(2); L.walk(6)
    L.face(4, "L", chute=True)
    L.walk(4); L.cairn(); L.walk(4); L.sign(2); L.walk(3)
    L.wind(8)
    L.spur(5, "gear:rope", windy=True)
    L.walk(6); L.slabs(); L.walk(5)
    L.face(5, "C", chute=True)
    L.walk(3); L.mark("R", 1); L.walk(5)
    L.ice(5); L.walk(4)
    L.face(4, "s")
    L.walk(4); L.cairn(); L.walk(4)
    L.wind(6)
    L.spur(5, "gear:shell", windy=True)
    L.walk(6)
    L.face(5, "C", chute=True)
    L.walk(4); L.sign(1); L.mark("V", 4); L.walk(6)
    L.spur(5, "artifact", chute=True, windy=True, raven=True)
    L.walk(8); L.cairn(); L.walk(4)
    L.down(5); L.rocks(8); L.down(4); L.rocks(8)
    L.finish(12)
    return {"every": 4, "kinds": ("hop", "plant", "pit", "ants", "ice", "hop", "plant", "ants"), "wildlife": True, "ravens": 0}


def karanga_valley(L):
    """Easy, with Marco. From the top of the wall down into the valley of
    giant groundsels, across the stream, and up its loose far side."""
    L.start(26, [(3, "T"), (6, "F"), (9, "p"), (13, "l"), (16, "j"), (20, "P")], sign_at=23)
    L.walk(6)
    L.spur(4, "gear:rope")
    L.walk(8); L.cairn(); L.walk(4)
    L.down(6); L.rocks(7); L.sign(1); L.walk(4)
    L.step(6)
    L.walk(6); L.cairn(); L.walk(4)
    L.spur(5, "gear:poles")
    L.walk(6); L.mark("g", 2); L.down(5); L.rocks(10); L.mark("o", 3); L.walk(6)
    L.sign(1); L.walk(4); L.mark("w", 1); L.walk(4)
    L.gap(2); L.walk(4); L.gap(2); L.walk(6)
    L.spur(5, "gear:gloves")
    L.walk(6); L.mark("g", 3); L.walk(6)
    L.mate()
    L.walk(4); L.mark("o", 2); L.walk(6)
    L.spur(7, "artifact", raven=True)
    L.walk(8)
    L.face(5, "s")
    L.walk(4); L.cairn(); L.walk(4); L.sign(2); L.walk(4)
    L.spur(5, "gear:helmet")
    L.walk(8)
    L.face(6, "L", chute=True)
    L.walk(5); L.mark("R", 1); L.walk(5); L.up(4); L.walk(6)
    L.face(7, "C")
    L.walk(4); L.cairn(); L.walk(4)
    L.wind(9)
    L.spur(6, "gear:shell", windy=True)
    L.walk(8)
    L.spur(8, "artifact", chute=True)
    L.walk(8); L.up(4); L.walk(6)
    L.sign(1); L.mark("T", 4); L.mark("F", 6); L.walk(8)
    L.finish(8)
    return {"every": 9, "kinds": ("hop", "plant", "hop", "ants"), "wildlife": True}


def barranco_wall(L):
    """Medium, with Marco. The wall: the scramble, Kissing Rock along a band
    over the drop, an exposed ledge, the loose gully, the shoulder, the
    plateau and the way on."""
    L.start(30, [(2, "g"), (4, "p"), (7, "T"), (10, "F"), (13, "T"), (17, "l"), (20, "j"), (24, "P")], sign_at=27)
    L.walk(8)
    L.spur(4, "gear:rope")
    L.walk(6); L.up(4); L.walk(8); L.cairn(); L.sign(4); L.walk(8)
    L.face(5, "s")
    L.walk(4); L.cairn(); L.walk(4)
    L.spur(6, "gear:gloves")
    L.walk(6)
    L.face(6, "C")
    L.walk(6)
    L.traverse(7)
    L.walk(4); L.cairn(); L.walk(4); L.sign(1); L.walk(3)
    L.wind(8)
    L.spur(6, "gear:shell", windy=True)
    L.walk(4)
    L.mate()
    L.walk(4)
    L.spur(7, "artifact", windy=True)
    L.walk(6); L.slabs(); L.walk(6)
    L.spur(5, "gear:helmet")
    L.walk(6)
    L.face(5, "L", chute=True, niche=True)
    L.walk(4); L.cairn(); L.walk(4); L.sign(1); L.walk(4)
    L.wind(8); L.walk(4)
    L.face(6, "C", chute=True)
    L.walk(5); L.mark("R", 1); L.walk(5)
    L.spur(8, "artifact", chute=True)
    L.walk(6); L.up(3); L.walk(6); L.cairn(); L.sign(4); L.mark("V", 7); L.walk(12)
    L.spur(4, "gear:poles")
    L.walk(6); L.roller(16)
    L.down(6); L.rocks(8)
    L.finish(12)
    return {"every": 6, "kinds": ("hop", "plant", "pit", "ants", "slabs", "raven", "hop", "ice"), "wildlife": True}


def arrow_glacier(L):
    """Hard, with Marco. Grey scree and old ice under the Western Breach in
    sleet: stones off the Breach on nearly every wall, rolling stones,
    slabs, the windy shoulder. A quarter of the bar."""
    L.start(26, [(3, "T"), (6, "F"), (9, "T"), (13, "l"), (16, "j"), (20, "P")], sign_at=23)
    L.walk(4)
    L.spur(4, "gear:helmet")
    L.walk(6); L.up(3); L.roller(14); L.cairn(); L.sign(3); L.walk(6)
    L.face(3, "L", chute=True)
    L.walk(3); L.mark("R", 1); L.walk(4)
    L.ice(6); L.walk(3)
    L.spur(5, "gear:crampons", chute=True)
    L.walk(6)
    L.face(4, "C", chute=True)
    L.walk(4); L.cairn(); L.walk(4)
    L.ice(8); L.walk(3)
    L.spur(5, "gear:gloves", chute=True)
    L.walk(5); L.slabs(); L.walk(4)
    L.face(3, "L", chute=True)
    L.walk(3); L.mark("R", 1); L.walk(4); L.sign(1); L.walk(3)
    L.wind(8)
    L.spur(5, "gear:shell", windy=True)
    L.walk(4)
    L.mate()
    L.walk(3)
    L.face(4, "C", chute=True)
    L.walk(4); L.cairn(); L.walk(4); L.sign(1); L.walk(4)
    L.spur(5, "artifact", chute=True, windy=True)
    L.walk(5); L.roller(12)
    L.face(3, "L", chute=True)
    L.walk(3); L.mark("R", 1); L.walk(4)
    L.crevasse(); L.walk(4)
    L.face(4, "C", chute=True)
    L.walk(4); L.cairn(); L.walk(4)
    L.spur(5, "gear:rope", chute=True)
    L.walk(5); L.slabs(); L.walk(4)
    L.spur(5, "artifact", chute=True, raven=True)
    L.walk(6); L.ice(6); L.walk(4); L.sign(1); L.mark("T", 6); L.mark("V", 9); L.walk(12)
    L.finish(10)
    return {"every": 4, "kinds": ("hop", "pit", "slabs", "ice", "raven", "hop", "pit"), "wildlife": False, "quiet": ("v", "#"), "ravens_spread": True}


def stella_point(L):
    """Easy, with Jun, at night. The zigzags of scree from Barafu, short
    rock steps, an icy patch, the rim with its windy saddles, Stella Point
    and the walk along the rim to Uhuru."""
    L.start(20, [(2, "T"), (5, "F"), (8, "l"), (10, "m"), (14, "P")], sign_at=17)
    L.walk(6)
    L.spur(4, "gear:headlamp")
    L.walk(6); L.up(4); L.walk(8); L.cairn(); L.walk(4)
    L.face(5, "s")
    L.walk(6); L.sign(1); L.walk(4); L.up(4); L.walk(6)
    L.ice(8); L.walk(4)
    L.spur(5, "gear:crampons")
    L.walk(6)
    L.mate()
    L.walk(4); L.up(5); L.walk(6)
    L.face(6, "C")
    L.walk(4); L.cairn(); L.walk(4)
    L.spur(5, "gear:rope")
    L.walk(6); L.up(4); L.walk(6)
    L.spur(7, "artifact", windy=True)
    L.walk(6)
    L.face(5, "L", chute=True)
    L.walk(4); L.cairn(); L.walk(3); L.sign(1); L.walk(4)
    L.wind(9); L.walk(3); L.cairn(); L.mark("R", 3); L.walk(6)
    L.spur(5, "gear:shell", windy=True)
    L.walk(4); L.wind(9); L.walk(4)
    L.spur(5, "gear:poles")
    L.walk(6)
    L.face(5, "C")
    L.rocks(6); L.cairn(); L.walk(4)
    L.spur(8, "artifact", chute=True)
    L.rocks(8); L.sign(1); L.mark("V", 5); L.walk(14)
    L.finish(16, summit=True)
    return {"every": 7, "kinds": ("hop", "raven", "pit", "raven", "hop", "ice"), "wildlife": False, "quiet": ("v", "#"), "ravens_spread": True}


def southern_icefields(L):
    """Medium, with Jun, before dawn. Blue ice runs, seracs, a crevasse,
    rock steps, the windy rim along the icefields to Uhuru."""
    L.start(20, [(2, "T"), (5, "F"), (8, "l"), (10, "m"), (14, "P")], sign_at=17)
    L.walk(6)
    L.spur(4, "gear:crampons")
    L.walk(6); L.up(4); L.walk(6); L.cairn(); L.walk(4)
    L.face(5, "s")
    L.walk(4); L.sign(1); L.walk(4)
    L.ice(14, clear=True); L.walk(4)
    L.spur(6, "gear:headlamp")
    L.walk(6); L.up(4); L.walk(4)
    L.face(6, "C", chute=True)
    L.walk(4); L.cairn(); L.walk(4)
    L.ice(8); L.walk(3)
    L.crevasse(); L.rocks(7)
    L.mate()
    L.walk(4)
    L.spur(6, "gear:rope")
    L.walk(6); L.ice(8); L.walk(4)
    L.face(5, "L", chute=True)
    L.walk(4); L.cairn(); L.walk(4)
    L.spur(6, "gear:helmet", chute=True)
    L.walk(6); L.slabs(); L.walk(5)
    L.spur(8, "artifact", chute=True)
    L.walk(6)
    L.face(6, "C")
    L.walk(4); L.cairn(); L.walk(3); L.sign(1); L.walk(3)
    L.wind(10); L.walk(3); L.cairn(); L.mark("R", 3); L.walk(5)
    L.spur(5, "gear:shell", windy=True)
    L.walk(4); L.ice(6); L.wind(10); L.walk(4); L.cairn(); L.walk(4)
    L.spur(5, "artifact", windy=True, raven=False)
    L.walk(6); L.up(3); L.walk(6); L.sign(1); L.mark("V", 5); L.walk(14)
    L.finish(16, summit=True)
    return {"every": 5, "kinds": ("hop", "raven", "pit", "ice", "slabs", "raven", "hop", "ice"), "wildlife": False, "quiet": ("v", "#"), "ravens_spread": True}


def western_breach(L):
    """Hard, with Jun, at night. The Breach's rock band: short walls with
    stones down nearly every gully, ice in the chimneys, slabs; then the
    crater rim in the wind, the crater floor's ice and crevasse, the last
    wall to Uhuru. A quarter of the bar."""
    L.start(20, [(2, "T"), (5, "F"), (8, "l"), (10, "m"), (14, "P")], sign_at=17)
    L.walk(4)
    L.spur(4, "gear:helmet")
    L.walk(6); L.up(3); L.walk(6); L.cairn(); L.walk(3)
    L.face(3, "L", chute=True)
    L.walk(3); L.mark("R", 1); L.walk(4); L.sign(1); L.walk(3)
    L.spur(4, "gear:headlamp", chute=True)
    L.walk(5)
    L.face(4, "C", chute=True)
    L.walk(4); L.cairn(); L.walk(3)
    L.ice(5); L.walk(3)
    L.spur(4, "gear:crampons", chute=True)
    L.walk(5)
    L.face(3, "L", chute=True)
    L.walk(3); L.mark("R", 1); L.walk(4)
    L.mate()
    L.walk(3)
    L.face(4, "C", chute=True)
    L.walk(4); L.cairn(); L.walk(3); L.slabs(); L.ice(6); L.walk(3)
    L.spur(4, "gear:rope", chute=True)
    L.walk(3); L.wind(7); L.cairn(); L.walk(2); L.slabs(); L.walk(3)
    L.face(4, "s", chute=True)
    L.walk(3); L.mark("R", 1); L.walk(4)
    L.spur(4, "artifact", chute=True, windy=True)
    L.walk(5)
    L.face(4, "C", chute=True)
    L.walk(4); L.cairn(); L.walk(3); L.sign(1); L.walk(3)
    L.wind(9); L.walk(3); L.breather(); L.rocks(6)
    L.down(4); L.walk(3); L.ice(8); L.walk(3)
    L.crevasse(); L.walk(3)
    L.spur(4, "gear:gloves")
    L.walk(4); L.ice(6); L.walk(4); L.cairn(); L.walk(4)
    L.spur(4, "artifact", chute=True, raven=False, windy=True)
    L.walk(2); L.mark("R", 1); L.walk(3)
    L.face(4, "C", chute=True)
    L.walk(3); L.mark("R", 1); L.walk(4)
    L.face(3, "L")
    L.walk(3); L.mark("R", 1); L.walk(3); L.ice(6); L.wind(6); L.mark("R", 1); L.rocks(6)
    L.sign(1); L.mark("V", 5); L.walk(12)
    L.finish(16, summit=True)
    return {"every": 3, "kinds": ("hop", "raven", "pit", "ice", "slabs", "raven", "hop", "pit"), "wildlife": False, "quiet": ("v", "#"), "ravens_spread": 6}


def way_down(route):
    """The way down from Stella Point to Barafu, for each route's weather:
    the rim in the wind with Jun, scree slopes, rock steps climbed down,
    ice above the last step, the finds on ledges off the line."""
    hard = {"lemosho": 0, "machame": 1, "umbwe": 2}[route]

    def build(L):
        L.start(14, [(2, "P"), (6, "V"), (9, "l")], sign_at=4)
        L.mate()
        L.wind(10 + 4 * hard)
        L.spur(4, "gear:shell", windy=True)
        L.walk(4); L.cairn(); L.walk(6)
        L.down(10); L.walk(6)
        L.spur(4, "gear:poles")
        L.walk(6); L.cairn(); L.walk(4)
        L.down(10 + 2 * hard); L.walk(4)
        if hard:
            L.slabs(); L.walk(4)
        L.spur(5 if hard < 2 else 4, "artifact", chute=hard == 1, windy=hard == 2)
        L.walk(6); L.cairn(); L.mark("R", 2); L.sign(4); L.walk(8)
        L.step(5)
        L.walk(6); L.cairn(); L.walk(4)
        L.down(10); L.walk(4)
        if hard:
            L.wind(8)
        L.walk(4)
        L.spur(4, "gear:crampons")
        L.walk(4); L.ice(6 + 2 * hard); L.walk(3)
        L.step(5)
        L.walk(4); L.mark("R", 2); L.sign(4); L.walk(8)
        L.spur(6 if hard < 2 else 4, "artifact", chute=True)
        L.walk(6)
        if hard == 2:
            L.down(8); L.walk(6)
            L.step(4)
            L.walk(6)
        L.down(10); L.walk(6); L.cairn(); L.sign(4)
        L.walk(8); L.mark("T", 2); L.mark("F", 5); L.mark("m", 7); L.mark("T", 10)
        L.finish(14)
        return {"every": [0, 9, 7][hard], "kinds": ("hop", "pit", "slabs", "ice", "hop"), "wildlife": False}

    build.__name__ = f"way_down_{route}"
    return build


PLACES = {
    "lava_tower": {"lemosho": shira_cathedral, "machame": lava_tower, "umbwe": umbwe_ridge},
    "barranco": {"lemosho": karanga_valley, "machame": barranco_wall, "umbwe": arrow_glacier},
    "summit_night": {"lemosho": stella_point, "machame": southern_icefields, "umbwe": western_breach},
    "descent": {r: way_down(r) for r in ROUTES},
}
SIGNS = {"lava_tower": 4, "barranco": 5, "summit_night": 4, "descent": 4}
# The spec's gear, in its order (the level script's "gear" list, by route).
GEAR_ORDER = {
    "lava_tower": {"lemosho": ["poles", "gloves", "shell", "rope", "helmet"],
                   "machame": ["rope", "shell", "helmet", "gloves", "poles"],
                   "umbwe": ["gloves", "helmet", "poles", "rope", "shell"]},
    "barranco": {"lemosho": ["rope", "poles", "gloves", "helmet", "shell"],
                 "machame": ["rope", "gloves", "helmet", "shell", "poles"],
                 "umbwe": ["helmet", "crampons", "gloves", "shell", "rope"]},
    "summit_night": {"lemosho": ["headlamp", "crampons", "rope", "shell", "poles"],
                     "machame": ["crampons", "headlamp", "shell", "rope", "helmet"],
                     "umbwe": ["helmet", "headlamp", "crampons", "rope", "gloves"]},
    "descent": {r: ["shell", "poles", "crampons"] for r in ROUTES},
}


def thin_wildlife(c):
    """One creature per stretch: nothing within eight tiles of another on the
    same stretch of the walk (a raven circles three rows up)."""
    kept = []
    for y in range(c.h):
        for x in range(c.w):
            if c.g[y][x] in "nav":
                if any(abs(x - kx) < 8 and abs(y - ky) <= 4 for kx, ky in kept):
                    c.g[y][x] = "."
                else:
                    kept.append((x, y))


def ravens_off_rests(c, reach=6):
    """No raven over a place the line sits down: a raven dives at whoever
    sits still under it."""
    rests = []
    for k, a in enumerate(c.script):
        if a[0] == "rest" and k > 0 and c.script[k - 1][0] == "walk":
            rests.append(c.script[k - 1][1])
    for y in range(c.h):
        for x in range(c.w):
            if c.g[y][x] == "v" and any(abs(x - rx) < reach for rx in rests):
                c.g[y][x] = "."


def fill_quiet(c, gap=9, kinds=("#",), rest_reach=7):
    """Nothing to do for more than `gap` tiles of the line (two seconds or
    so at a walk) gets something: a boulder to hop, or a raven
    circling over it (never over a place the line sits down)."""
    rests = [c.script[k - 1][1] for k, a in enumerate(c.script)
             if a[0] == "rest" and k > 0 and c.script[k - 1][0] == "walk"]
    exits = [(x, y) for y in range(c.h) for x in range(c.w) if c.g[y][x] == "X"]
    busy = set("nav#KSRw*VTFlmjpMPXrbdgo")
    last = 0
    turn = 0
    for i, (x, y) in enumerate(c.path):
        here, below = c.get(x, y), c.get(x, y + 1)
        # Challenges only: cairns, signs and finds are something to see,
        # not something to deal with.
        eventful = (here in "nav#rbd" or here == "E" or below in "ic" or c.get(x, y - 3) == "v"
                    or any(c.get(xx, yy) in "CLs" for xx in range(x - 1, x + 2) for yy in range(y - 4, y + 2)))
        if eventful:
            last = i
            continue
        if i - last < gap:
            continue
        fair = (here == "." and below == "#"
                and all(c.get(xx, y) == "." and c.get(xx, y + 1) in SOLID for xx in (x - 2, x - 1, x + 1, x + 2))
                and all(c.get(xx, yy) == "." for xx in range(x - 2, x + 3) for yy in range(y - 4, y))
                and not any(c.get(xx, yy) in busy - {"#"} for xx in range(x - 3, x + 4) for yy in range(y - 2, y + 1))
                and all(abs(x - ex) > 9 or abs(y - ey) > 3 for ex, ey in exits))
        if not fair:
            continue
        kind = kinds[turn % len(kinds)]
        if kind == "v" and any(abs(x - rx) < rest_reach for rx in rests):
            kind = "#"
        if kind == "v":
            c.put(x, y - 3, "v")
        else:
            c.put(x, y, "#")
        turn += 1
        last = i


def place_ravens(c, n=5, rest_reach=7):
    """Ravens spread along the whole line, bottom to top (the high, bare
    places with nothing else living): one in each of n stretches, over open
    ground, away from where the line sits down and from other creatures."""
    rests = [c.script[k - 1][1] for k, a in enumerate(c.script)
             if a[0] == "rest" and k > 0 and c.script[k - 1][0] == "walk"]
    path = c.path
    have = [(x, y) for y in range(c.h) for x in range(c.w) if c.g[y][x] in "nav"]
    for k in range(n):
        lo, hi = len(path) * k // n, len(path) * (k + 1) // n
        if any(path[lo][0] <= hx <= path[hi - 1][0] for hx, hy in have):
            continue
        for i in range(lo + (hi - lo) // 2, hi):
            x, y = path[i]
            if (c.get(x, y) == "." and c.get(x, y + 1) == "#" and c.get(x, y - 3) == "."
                    and all(c.get(x, yy) == "." for yy in range(y - 4, y))
                    and all(abs(x - rx) >= rest_reach for rx in rests)
                    and not any(c.get(xx, yy) in "EKSPXM" for xx in range(x - 6, x + 7) for yy in range(y - 1, y + 1))
                    and all(abs(x - hx) >= 8 or abs(y - hy) > 4 for hx, hy in have)):
                c.put(x, y - 3, "v")
                have.append((x, y - 3))
                break


def clear_before_exit(c, n=7):
    """Nothing to hop just before the exit post."""
    for y in range(c.h):
        for x in range(c.w):
            if c.g[y][x] == "X":
                for dx in range(1, n + 1):
                    for xx in (x - dx, x + dx):
                        if 0 <= xx < c.w and c.g[y][xx] in "#nab" and c.g[y + 1][xx] in SOLID:
                            c.g[y][xx] = "."
                        if 0 <= xx < c.w and c.g[y + 1][xx] == "." and c.g[y + 2][xx] == ".":
                            c.g[y + 1][xx] = "#"      # a pit: filled


def run(fn, route, W, H, y0, seed):
    c = Course(W, H, seed)
    c.fill(0, 0, 0, H - 1, "#")
    L = Line(c, route, 1, y0)
    g = fn(L)
    for x, nf in c.niches:
        c.fill(x, nf - 3, x + 1, nf - 1, ".")
    return c, L, g


def build(name, route):
    fn = PLACES[name][route]
    seed = zlib.crc32(f"{name}:{route}".encode()) & 0xffff
    # Measure, then lay it out in a map just big enough.
    _, probe, _ = run(fn, route, 1600, 400, 300, seed)
    H = (probe.max_y - probe.min_y) + SKY + DEEP
    y0 = 300 - probe.min_y + SKY
    W = probe.x + 1
    c, L, g = run(fn, route, W, H, y0, seed)
    # The artifacts' ledges are not on the map: hold their cells while the
    # gauntlet lines the walks, so nothing lands on one.
    for x, y in c.artifacts:
        c.put(x, y, "T")
    if g["every"]:
        gauntlet(c.g, every=g["every"], kinds=g["kinds"], raven_max=g.get("ravens", 12))
        if g["wildlife"]:
            wildlife(c.g, every=max(4, g["every"] - 2), kinds=("ants", "plant"))
        thin_wildlife(c)
    ravens_off_rests(c)
    if g.get("ravens_spread"):
        place_ravens(c, 5 if g["ravens_spread"] is True else g["ravens_spread"])
    fill_quiet(c, kinds=g.get("quiet", ("#",)))
    clear_before_exit(c)
    for x0, x1, row in c.clear_spans:
        for x in range(x0, x1 + 1):
            if c.g[row][x] in "#inav":
                c.g[row][x] = "."
            if c.g[row - 3][x] == "v":
                c.g[row - 3][x] = "."
    for x, y in c.artifacts:
        c.put(x, y, ".")
    order = GEAR_ORDER[name][route]
    assert sorted(order) == sorted(c.gear), (name, route, "gear", order, list(c.gear))
    side = {
        "route": route,
        "place": fn.__name__,
        "cairns": c.cairns,
        "signs": c.signs,
        "gear": [list(c.gear[k]) for k in order],
        "artifacts": c.artifacts,
        "mate": c.mate,
        "script": c.script,
    }
    return c, side


def check(name, route, c, side):
    """What every climb needs, and fair play."""
    g = c.g
    count = lambda ch: sum(row.count(ch) for row in g)
    assert count("P") == 1 and count("X") == 1, (name, route, "start and exit")
    assert count("K") == len(side["cairns"]) >= 4, (name, route, "cairns", count("K"), len(side["cairns"]))
    assert count("S") == len(side["signs"]) == SIGNS[name], (name, route, "signs", count("S"), len(side["signs"]))
    assert count("*") == len(side["gear"]), (name, route, "gear")
    assert len(side["artifacts"]) == 2, (name, route, "artifacts")
    assert count("r") >= 1, (name, route, "stonefall")
    for x, y in side["gear"] + side["artifacts"]:
        assert g[y][x] in ".E*" and g[y + 1][x] in SOLID, (name, route, "on ground", x, y, g[y][x], g[y + 1][x])
        # Off the line: nowhere on the path you walk.
        assert all(abs(px - x) > 0 or abs(py - y) > 2 for px, py in c.path), (name, route, "a find on the path", x, y)


def preview(c, path):
    from PIL import Image
    colours = {
        "#": (70, 60, 52), "/": (90, 78, 66), "\\": (90, 78, 66), "C": (140, 120, 100), "L": (170, 140, 110),
        "s": (150, 130, 110), "E": (200, 120, 120), ".": (150, 180, 205), "K": (240, 220, 80), "R": (90, 160, 90),
        "P": (60, 200, 60), "X": (220, 60, 60), "M": (230, 110, 50), "S": (200, 160, 90),
        "i": (200, 235, 255), "c": (120, 60, 160), "r": (255, 0, 0), "w": (0, 90, 255), "*": (255, 255, 0),
        "b": (255, 120, 0), "d": (255, 120, 0), "n": (40, 140, 40), "a": (120, 40, 20), "v": (10, 10, 10),
    }
    img = Image.new("RGB", (c.w, c.h))
    px = img.load()
    for y in range(c.h):
        for x in range(c.w):
            px[x, y] = colours.get(c.g[y][x], (255, 255, 255))
    img.resize((c.w * 4, c.h * 4), Image.NEAREST).save(path)


def main():
    out_dir = None
    if "--preview" in sys.argv:
        out_dir = Path(sys.argv[sys.argv.index("--preview") + 1])
        out_dir.mkdir(parents=True, exist_ok=True)
    for name in PLACES:
        for route in ROUTES:
            c, side = build(name, route)
            check(name, route, c, side)
            base = LEVELS / name / f"{name}_{route}"
            base.with_suffix(".txt").write_text(c.text())
            base.with_suffix(".json").write_text(json.dumps(side, indent=1) + "\n")
            print(f"{name:13} {route:8} {side['place']:19} {c.w}x{c.h}  cairns {len(side['cairns'])}"
                  f"  walls {sum(1 for a in side['script'] if a[0] in ('climb', 'down'))}"
                  f"  finds {sum(1 for a in side['script'] if a[0] == 'fetch')}")
            if out_dir:
                preview(c, out_dir / f"{name}_{route}.png")


if __name__ == "__main__":
    main()
