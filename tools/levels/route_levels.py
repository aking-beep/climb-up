"""
The Kilimanjaro climbs, laid out for each route. The route you pick at the
gate sets how hard every played climb is, so each climb is built three ways:

  lemosho  the long way    easy: short benches, low faces, little exposure
  machame  the faster way  medium
  umbwe    the fastest way hard: long benches, tall loose faces, stonefall,
                           wind, ice and cracked slabs

Same places, same people and the same story on every route; different
ground. For each climb and route this writes

  godot/modes/expedition/levels/kilimanjaro/<climb>/<climb>_<route>.txt
  godot/modes/expedition/levels/kilimanjaro/<climb>/<climb>_<route>.json

Legend (one character per 16 px tile; core/world/terrain.gd reads it):
  #  rock (solid)              /  slope rising right    \\  slope rising left
  C  climbable face            L  loose scree face      s  scramble boulders
  E  exposed ground (wind)     R  rest stone            K  cairn (checkpoint)
  i  ice                       c  cracked slab          r  stonefall chute
  b / d  a stone rolls left / right from here           w  water cache
  *  lost gear                 n  thistle   a  siafu    v  raven
  P  start   X  exit   M  the teammate who needs help
  l Lena  j Jun  m Marco  p porter  S sign  T tent  F fire  V vista
  g groundsel  o lobelia       .  air (inside the mountain, the back wall)

The JSON is
what the map alone cannot say: the cairns and signs in the order you reach
them, where each piece of gear and each artifact lies, the teammate and the
way you pass them, and the line a climber takes (a script the level tests'
bot follows: tests/climb_bot.gd follow()).

Built from the pieces the level tests already prove: benches (shelves with
six rows of air), three-wide step faces at a bench's end, stonefall over a
face, a niche halfway up a tall one, a band of rock across a void, scree
ramps and rock steps climbed down. tools/levels/gauntlet.py then lines the
walks with challenges, more often on harder routes.

    python3 tools/levels/route_levels.py [--preview <dir>]

Game fiction inspired by the place, not a description of the real routes.
"""

import json
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gauntlet import gauntlet, wildlife  # noqa: E402
from gear import place as place_near  # noqa: E402

ROOT = HERE.parents[1]
LEVELS = ROOT / "godot" / "modes" / "expedition" / "levels" / "kilimanjaro"
ROUTES = ("lemosho", "machame", "umbwe")
HD = 6           # rows of air over a bench floor
SOLID = set("#/\\ic")
MARKERS = set("PXMljmpSTFgoVKRrw*bdnav")


class Course:
    def __init__(self, w, h, seed):
        self.w, self.h = w, h
        self.g = [["#" for _ in range(w)] for _ in range(h)]
        self.rnd = random.Random(seed)
        self.script = []
        self.cairns = []          # in the order you reach them
        self.signs = []
        self.gear = {}            # kind -> target (x, y) near which it goes
        self.path = []            # standing cells along the line, in order
        self.mate = None
        self.danger = []          # (x, y, weight) spots worth an artifact

    # --- drawing ---------------------------------------------------------
    def fill(self, x0, y0, x1, y1, ch):
        for y in range(max(0, y0), min(self.h - 1, y1) + 1):
            for x in range(max(0, x0), min(self.w - 1, x1) + 1):
                self.g[y][x] = ch

    def put(self, x, y, ch):
        self.g[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        return "#"

    def walk_cells(self, x0, x1, y):
        step = 1 if x1 >= x0 else -1
        for x in range(x0, x1 + step, step):
            self.path.append((x, y))

    # --- the line --------------------------------------------------------
    def say(self, *action):
        self.script.append(list(action))

    def cairn(self, x, y):
        self.put(x, y, "K")
        self.cairns.append([x, y])

    def sign(self, x, y):
        self.put(x, y, "S")
        self.signs.append([x, y])

    def text(self):
        return "\n".join("".join(r) for r in self.g) + "\n"


# --- Ascents: camp, an approach, switchback benches, the top -----------------

def ascent(c, *, CF, camp_w, approach, ramp, XA, XB, gaps, kinds, top_floor, hole=False):
    """Lays the camp, the approach and the benches; returns the floors. Bench
    0 is the approach's end inside the mountain (walk right); each step i is
    a face at the end of bench i, up to bench i+1; the walk turns at each."""
    XW = XA - 1
    fA = CF - ramp
    floors = [fA]
    for gp in gaps:
        floors.append(floors[-1] - gp)
    assert floors[-1] == top_floor, (floors, top_floor)
    # Sky over the camp and the approach; the camp floor and the ramp.
    rs = camp_w + 4                      # ramp start column
    c.fill(0, 0, XW - 1, CF - 1, ".")
    for i in range(ramp):
        x, y = rs + i, CF - 1 - i
        c.put(x, y, "/")
        c.fill(x, y + 1, x, c.h - 1, "#")
    c.fill(rs + ramp, fA, XW - 1, c.h - 1, "#")
    c.fill(rs + ramp, 0, XW - 1, fA - 1, ".")
    c.fill(0, 0, 0, CF - 1, "#")         # the world's west edge
    if hole:
        # A stream cut out of camp, open to the bottom of the map: hop it, or
        # fall in and start the climb again.
        c.fill(camp_w + 1, CF, camp_w + 2, c.h - 1, ".")
    # Benches inside the mountain (the top one is open sky).
    for i, f in enumerate(floors[:-1]):
        c.fill(XA, f - HD, XB, f - 1, ".")
    c.fill(XW, fA - HD, XW, fA - 1, ".")  # the way in, off the approach
    c.fill(XW, 0, c.w - 1, floors[-1] - 1, ".")
    # Step faces at the end you walk toward.
    for i, kind in enumerate(kinds):
        lo, hi = floors[i], floors[i + 1]
        cx = XB - 2 if i % 2 == 0 else XA
        c.fill(cx, hi, cx + 2, lo - 1, kind)
    return floors


def face_cols(i, XA, XB):
    return (XB - 2) if i % 2 == 0 else XA


def climb_step(c, i, floors, XA, XB, *, chute=False, niche=False, kind="C", then=None):
    """The line up step i: walk to the face, rest, wait out its stones,
    climb (into the niche on the way up a tall one), and pull over toward
    `then`, the way the walk goes next (by default back along the next
    bench; off the last step, on toward the exit). Never over the face's
    own top: those cells are rock to climb, not ground."""
    fc = face_cols(i, XA, XB)
    right = i % 2 == 0
    lo, hi = floors[i], floors[i + 1]
    if chute:
        c.put(fc + 1, hi - 5, "r")
    nich = None
    if niche:
        assert right, "a niche is cut into the rock beside a right-hand face"
        nf = (lo + hi) // 2
        c.fill(fc + 3, nf - 3, fc + 4, nf - 1, ".")
        nich = {"row": nf, "x": fc + 3.6, "back": fc + 2.4}
    # A boulder on the walk up to the face: the stamper keeps clear of faces,
    # so without it the last stretch before one is just walking.
    hx = fc - 7 if right else fc + 9
    if all(c.get(x, lo - 1) == "." and c.get(x, lo) == "#" for x in (hx - 1, hx, hx + 1)):
        c.put(hx, lo - 1, "#")
    rest_x = fc - 3.0 if right else fc + 5.5
    c.say("walk", rest_x)
    c.say("rest", 0.98)
    lean = then if then is not None else (-1 if right else 1)
    c.say("climb", {"x": fc + 1.5, "dir": 1 if right else -1, "row": hi, "lean": lean,
                    "chute": chute, "niche": nich, "kind": kind})
    # Cairn where the step tops out, a few tiles along the next bench.
    kx = fc - 4 if right else fc + 6
    c.cairn(kx, hi - 1)
    return kx


def bench_walk(c, i, floors, XA, XB):
    """Standing cells of bench i in the direction you walk it."""
    f = floors[i]
    if i % 2 == 0:
        c.walk_cells(XA + 3 if i else XA - 1, XB - 3, f - 1)
    else:
        c.walk_cells(XB - 3, XA + 3, f - 1)


def exposed(c, x0, x1, f, weight=3):
    for x in range(x0, x1 + 1):
        if c.get(x, f - 1) == ".":
            c.put(x, f - 1, "E")
            c.danger.append((x, f - 1, weight))


def ice(c, x0, x1, f):
    for x in range(x0, x1 + 1):
        if c.get(x, f) == "#":
            c.put(x, f, "i")
            c.danger.append((x, f - 1, 2))


def slab_bridge(c, x, f, depth=5):
    """Cracked slabs over a pit: keep walking."""
    c.fill(x, f, x + 1, f + depth - 1, ".")
    c.fill(x, f, x + 1, f, "c")
    for xx in (x - 1, x, x + 1, x + 2):
        c.danger.append((xx, f - 1, 4))


def traverse(c, f, vx0, vx1, dir_):
    """A band of rock across a void on a bench (the Barranco traverse):
    grab it and move along it; a fall lands in the void, a slip."""
    c.fill(vx0, f, vx1, f + 4, ".")              # the void
    c.fill(vx0 - 1, f - 4, vx1 + 1, f - 1, "C")  # the band
    c.fill(vx0 - 1, f - HD, vx1 + 1, f - 5, "#")  # rock over it
    # Stand under the band's overhang column (it is over solid floor), grab
    # it, and move along it until standing on the far side.
    end = vx0 - 2.0 if dir_ < 0 else vx1 + 2.0
    start = vx1 + 1.5 if dir_ < 0 else vx0 - 0.5
    c.say("walk", start)
    c.say("rest", 0.98)
    c.say("traverse", {"to": end, "dir": dir_, "row": f - 4})
    for x in range(vx0, vx1 + 1):
        c.danger.append((x, f - 1, 5))


def put_on_ground(c, x, y, ch):
    """A marker on the nearest open cell with rock under it along the row."""
    for dx in sorted(range(-12, 13), key=abs):
        if c.get(x + dx, y) == "." and c.get(x + dx, y + 1) in "#":
            c.put(x + dx, y, ch)
            return
    raise AssertionError(("no ground for", ch, x, y))


def people_at_camp(c, f, cells):
    for x, ch in cells:
        c.put(x, f - 1, ch)


def finish_walkdown(c, ftop, x_from, x_top_end, drop, x_exit):
    """The top: walk on, then a scree ramp down to the exit."""
    for i in range(drop):
        x, y = x_top_end + 1 + i, ftop + i
        c.fill(x, 0, x, y - 1, ".")
        c.put(x, y, "\\")
        c.fill(x, y + 1, x, c.h - 1, "#")
    low = ftop + drop
    c.fill(x_top_end + drop + 1, 0, c.w - 2, low - 1, ".")
    c.fill(x_top_end + drop + 1, low, c.w - 2, c.h - 1, "#")
    c.fill(c.w - 1, 0, c.w - 1, c.h - 1, "#")
    c.put(x_exit, low - 1, "X")
    # A boulder at the foot of the scree, so the walk out is not just walking.
    c.put(x_top_end + drop + 2, low - 1, "#")
    c.put(x_top_end + drop + 11, low - 1, "#")
    c.walk_cells(x_from, x_top_end, ftop - 1)
    c.walk_cells(x_top_end + drop + 1, x_exit, low - 1)
    return low


# --- The Lava Tower ----------------------------------------------------------

LAVA = {
    #           benches inside the tower, faces, and what is on them
    "lemosho": {"bench": 34, "gaps": [7, 7, 9], "kinds": ["s", "C", "C"], "chutes": [2], "niche": [],
                "wind": [(2, 0.35, 6)], "slabs": [], "rollers": [], "approach": 34, "ramp": 4,
                "top": 26, "drop": 7, "every": 8, "kindsG": ("hop", "plant", "hop", "ants"), "water": [1, 2], "rests": [1, 2]},
    "machame": {"bench": 46, "gaps": [8, 9, 12, 8], "kinds": ["s", "L", "C", "C"], "chutes": [2], "niche": [2],
                "wind": [(2, 0.3, 9)], "slabs": [(1, 0.45)], "rollers": [4], "approach": 44, "ramp": 6,
                "top": 36, "drop": 9, "every": 6, "kindsG": ("hop", "plant", "pit", "raven", "slabs", "ants", "ice"), "water": [1], "rests": [2]},
    "umbwe":   {"bench": 58, "gaps": [9, 11, 9, 11, 14], "kinds": ["s", "L", "C", "L", "C"], "chutes": [2, 4], "niche": [4],
                "wind": [(2, 0.25, 12), (3, 0.3, 10)], "slabs": [(1, 0.4), (3, 0.62)], "rollers": [4, 5], "approach": 52, "ramp": 7,
                "top": 46, "drop": 9, "every": 5, "kindsG": ("hop", "pit", "plant", "slabs", "raven", "ants", "ice", "pit"), "water": [2], "rests": [2]},
}


def lava_tower(route):
    p = LAVA[route]
    gaps, kinds = p["gaps"], p["kinds"]
    TOPF = 16
    CF = TOPF + sum(gaps) + p["ramp"]
    H = CF + 8
    camp_w = 30
    XA = camp_w + 4 + p["ramp"] + p["approach"] + 1
    XB = XA + p["bench"] - 1
    top_end = XB + p["top"]
    W = top_end + p["drop"] + 24
    c = Course(W, H, seed=hash(("lava", route)) & 0xffff)
    floors = ascent(c, CF=CF, camp_w=camp_w, approach=p["approach"], ramp=p["ramp"], XA=XA, XB=XB,
                    gaps=gaps, kinds=kinds, top_floor=TOPF, hole=True)
    f0 = CF - 1
    people_at_camp(c, CF, [(3, "g"), (6, "T"), (10, "F"), (13, "T"), (17, "m"), (20, "l"), (25, "P"), (28, "o")])
    c.sign(30, f0)                                   # sign 0: Shira 2
    c.walk_cells(25, camp_w + 3, f0)
    c.walk_cells(camp_w + 4 + p["ramp"], XA - 1, floors[0] - 1)
    c.gear["rope"] = (camp_w + 8 + p["ramp"], floors[0] - 1)
    c.cairn(XA - 3, floors[0] - 1)                   # cairn 1, the tower foot
    c.sign(XA - 6, floors[0] - 1)                    # sign 1: the tower foot
    c.gear["gloves"] = (XA + p["bench"] // 2, floors[0] - 1)
    # Up the tower.
    for i in range(len(kinds)):
        bench_walk(c, i, floors, XA, XB)
        if i == 2:
            c.gear["shell"] = (XB - 8, floors[2] - 1)
        if i + 1 == len(kinds):
            c.gear["helmet"] = ((XB - 6) if i % 2 == 0 else (XA + 6), floors[i] - 1)
        climb_step(c, i, floors, XA, XB, chute=i in p["chutes"], niche=i in p["niche"], kind=kinds[i],
                   then=1 if i + 1 == len(kinds) else None)
    for b, frac, n in p["wind"]:
        x0 = XA + int((XB - XA) * frac)
        exposed(c, x0, x0 + n - 1, floors[b])
        if b == 2 and not any(s for s in c.signs[2:]):
            pass
    # Sign 2 on the windy bench, just before the wind.
    b, frac, n = p["wind"][0]
    wx = XA + int((XB - XA) * frac)
    c.sign(wx + n + 2 if b % 2 else wx - 3, floors[b] - 1)
    for b, frac in p["slabs"]:
        slab_bridge(c, XA + int((XB - XA) * frac), floors[b])
    for b in p["water"]:
        put_on_ground(c, XA + (XB - XA) // 2 + 3, floors[b] - 1, "w")
    for b in p["rests"]:
        c.put((XB - 9) if b % 2 == 0 else (XA + 9), floors[b] - 1, "R")
    # The top of the tower, the walk on, the way down to the exit.
    ft = floors[-1]
    n = len(kinds)
    arrive_right = (n - 1) % 2 == 0      # last step at the right end
    c.fill(XA - 1, ft - 3, XA - 1, ft - 1, "#")   # a lip at the tower's west edge
    c.sign((XB - 9) if arrive_right else (XA + 9), ft - 1)   # sign 3: the top
    c.put(XB + 4, ft - 1, "V")
    if not arrive_right:
        c.walk_cells(XA + 3, XB, ft - 1)
    low = finish_walkdown(c, ft, XB - 3, top_end, p["drop"], W - 6)
    c.gear["poles"] = (top_end - 10, ft - 1)
    for k, b in enumerate(p["rollers"]):
        if b == len(kinds):
            c.put(top_end - 6 - 14 * k, ft - 1, "b")
    c.cairn(top_end - 2, ft - 1)
    c.put(top_end + p["drop"] + 6, low - 1, "o")
    c.say("walk", top_end - 1.5)
    c.say("rest", 0.95)
    c.say("finish", 1)
    return c, floors, {"kindsG": p["kindsG"], "every": p["every"], "wildlife": True}


# --- The Barranco Wall --------------------------------------------------------

BARRANCO = {
    "lemosho": {"bench": 40, "gaps": [7, 8, 8, 10], "kinds": ["s", "C", "C", "L"], "gully": 3, "niche": False,
                "traverse": None, "marco": (3, 0.5), "wind": [(3, 0.2, 6)], "slabs": [], "chutes": [3],
                "approach": 30, "ramp": 5, "top": 40, "drop": 6, "every": 8,
                "kindsG": ("hop", "plant", "hop", "ants"), "water": [2, 3], "rests": [1, 3]},
    "machame": {"bench": 52, "gaps": [8, 9, 14, 9, 14], "kinds": ["s", "C", "C", "C", "L"], "gully": 4, "niche": True,
                "traverse": (3, 0.45, 7), "marco": (4, 0.55), "wind": [(4, 0.15, 10)], "slabs": [(4, 0.35)], "chutes": [4],
                "approach": 36, "ramp": 8, "top": 56, "drop": 8, "every": 6,
                "kindsG": ("hop", "plant", "pit", "ants", "slabs", "raven", "hop", "plant", "ice", "ants"), "water": [3], "rests": [3]},
    "umbwe":   {"bench": 62, "gaps": [9, 10, 14, 10, 14, 15], "kinds": ["s", "L", "C", "C", "L", "C"], "gully": 4, "niche": True,
                "traverse": (3, 0.4, 10), "marco": (5, 0.5), "wind": [(5, 0.12, 14), (4, 0.25, 10)], "slabs": [(5, 0.3), (2, 0.5)],
                "chutes": [4, 5], "approach": 40, "ramp": 9, "top": 70, "drop": 10, "every": 5,
                "kindsG": ("hop", "pit", "plant", "slabs", "ants", "raven", "ice", "pit", "plant"), "water": [3], "rests": [3]},
}


def barranco(route):
    p = BARRANCO[route]
    gaps, kinds = p["gaps"], p["kinds"]
    TOPF = 14
    CF = TOPF + sum(gaps) + p["ramp"]
    H = CF + 8
    camp_w = 34
    XA = camp_w + 4 + p["ramp"] + p["approach"] + 1
    XB = XA + p["bench"] - 1
    top_end = XB + p["top"]
    W = top_end + p["drop"] + 26
    c = Course(W, H, seed=hash(("barranco", route)) & 0xffff)
    floors = ascent(c, CF=CF, camp_w=camp_w, approach=p["approach"], ramp=p["ramp"], XA=XA, XB=XB,
                    gaps=gaps, kinds=kinds, top_floor=TOPF, hole=True)
    f0 = CF - 1
    people_at_camp(c, CF, [(2, "g"), (4, "p"), (7, "T"), (10, "F"), (13, "T"), (17, "l"), (20, "j"), (24, "P"), (29, "o")])
    c.sign(31, f0)                                   # sign 0: Barranco Camp
    c.walk_cells(24, camp_w + 3, f0)
    c.walk_cells(camp_w + 4 + p["ramp"], XA - 1, floors[0] - 1)
    c.cairn(XA - 3, floors[0] - 1)                   # cairn 1, the wall foot
    c.sign(XA - 6, floors[0] - 1)                    # sign 1: the wall
    c.gear["rope"] = (XA + 6, floors[0] - 1)
    c.gear["gloves"] = (XB - 10, floors[0] - 1)
    mb, mfrac = p["marco"]
    for i in range(len(kinds)):
        bench_walk(c, i, floors, XA, XB)
        right = i % 2 == 0
        if p["traverse"] and p["traverse"][0] == i:
            _, frac, n = p["traverse"]
            vx0 = XA + int((XB - XA) * frac)
            traverse(c, floors[i], vx0, vx0 + n - 1, 1 if right else -1)
        if i == mb:
            # Marco on this bench, on the exposed stretch, with a cairn.
            mx = XA + int((XB - XA) * mfrac)
            wind = [w for w in p["wind"] if w[0] == i]
            if wind:
                _, frac, n = wind[0]
                x0 = XA + int((XB - XA) * frac) if right else mx + 6
                exposed(c, x0, x0 + n - 1, floors[i])
                c.sign(x0 - 2 if right else x0 + n + 1, floors[i] - 1)   # sign 2: exposed
                c.gear["shell"] = (x0 - 5 if right else x0 + n + 5, floors[i] - 1)
            c.put(mx, floors[i] - 1, "M")
            c.cairn(mx - 1 if right else mx + 1, floors[i] - 1)
            c.mate = {"cell": [mx, floors[i] - 1], "passDir": 1 if right else -1}
            c.say("walk", (mx - 6.5) if right else (mx + 7.5))
            c.say("mate", {"dir": 1 if right else -1, "choice": "help"})
            c.say("rest", 0.98)
        else:
            for b, frac, n in p["wind"]:
                if b == i:
                    x0 = XA + int((XB - XA) * frac)
                    exposed(c, x0, x0 + n - 1, floors[i])
        if i + 1 == p["gully"] + 1 or i == p["gully"]:
            c.gear.setdefault("helmet", ((XB - 7) if right else (XA + 7), floors[i] - 1))
        climb_step(c, i, floors, XA, XB, chute=i in p["chutes"], niche=p["niche"] and i == p["gully"],
                   kind=kinds[i], then=1 if i + 1 == len(kinds) else None)
    for b, frac in p["slabs"]:
        x = XA + int((XB - XA) * frac)
        if all(c.get(xx, floors[b] - 1) in ".E" for xx in range(x - 1, x + 3)):
            slab_bridge(c, x, floors[b])
    for b in p["water"]:
        put_on_ground(c, XA + (XB - XA) // 2 - 4, floors[b] - 1, "w")
    for b in p["rests"]:
        c.put((XB - 9) if b % 2 == 0 else (XA + 9), floors[b] - 1, "R")
    ft = floors[-1]
    n = len(kinds)
    arrive_right = (n - 1) % 2 == 0
    c.fill(XA - 1, ft - 3, XA - 1, ft - 1, "#")
    c.put((XB - 12) if arrive_right else (XA + 12), ft - 1, "V")
    c.sign((XB - 9) if arrive_right else (XA + 9), ft - 1)   # sign 3: the shoulder
    if not arrive_right:
        c.walk_cells(XA + 3, XB, ft - 1)
    # The plateau: a rise to the top of the wall, then down to Karanga.
    rx = XB + p["top"] // 3
    for i in range(3):
        c.put(rx + i, ft - 1 - i, "/")
        c.fill(rx + i, ft - i, rx + i, ft, "#")
    c.fill(rx + 3, ft - 3, rx + 12, ft - 1, "#")
    for i in range(3):
        c.put(rx + 13 + i, ft - 3 + i, "\\")
    c.cairn(rx - 6, ft - 1)
    c.sign(rx + 6, ft - 4)                           # sign 4: top of the wall
    c.put(rx + 9, ft - 4, "V")
    c.gear["poles"] = (top_end - 8, ft - 1)
    low = finish_walkdown(c, ft, XB - 3, top_end, p["drop"], W - 6)
    c.put(top_end - 5, ft - 1, "b") if route != "lemosho" else None
    c.put(top_end + p["drop"] + 8, low - 1, "g")
    c.say("walk", rx - 5.5)
    c.say("rest", 0.95)
    c.say("finish", 1)
    return c, floors, {"kindsG": p["kindsG"], "every": p["every"], "wildlife": True}


# --- Summit night -----------------------------------------------------------

SUMMIT = {
    "lemosho": {"bench": 52, "gaps": [8, 8, 8, 9], "kinds": ["s", "C", "L", "C"], "chutes": [3], "jun": 2,
                "ice": [(1, 0.25, 14)], "crevasse": None, "saddles": [8], "stella": 6, "slabs": [],
                "every": 6, "kindsG": ("hop", "pit", "raven", "hop", "ice"), "water": [1], "rests": [3]},
    "machame": {"bench": 64, "gaps": [8, 8, 9, 8, 9, 8], "kinds": ["s", "L", "C", "s", "L", "C"], "chutes": [3, 5], "jun": 3,
                "ice": [(1, 0.2, 30), (3, 0.6, 12)], "crevasse": (3, 0.5), "saddles": [10, 10], "stella": 8, "slabs": [(5, 0.45)],
                "every": 6, "kindsG": ("hop", "pit", "raven", "slabs", "hop", "ice", "pit"), "water": [3], "rests": [3, 4]},
    "umbwe":   {"bench": 84, "gaps": [10, 10, 11, 10, 11, 10], "kinds": ["L", "C", "L", "s", "L", "C"], "chutes": [4, 5], "jun": 3,
                "ice": [(1, 0.15, 36), (3, 0.55, 18), (5, 0.3, 16)], "crevasse": (3, 0.45), "saddles": [12, 12, 10], "stella": 10,
                "slabs": [(6, 0.4), (2, 0.6)], "every": 5, "kindsG": ("hop", "pit", "raven", "slabs", "ice", "pit", "hop"), "water": [3], "rests": [4]},
}


def summit_night(route):
    p = SUMMIT[route]
    gaps, kinds = p["gaps"], p["kinds"]
    # The last switchback tops out at the rim's west end, so the whole rim
    # (its saddles in the wind) is walked: an even number of steps.
    assert len(kinds) % 2 == 0, (route, "summit steps")
    TOPF = p["stella"] + 14
    CF = TOPF + sum(gaps)
    H = CF + 8
    camp_w = 18
    XA = camp_w + 4 + 4
    XB = XA + p["bench"] - 1
    rim_end = XB + 4
    XS = rim_end                     # the Stella step
    W = XS + 26
    c = Course(W, H, seed=hash(("summit", route)) & 0xffff)
    floors = ascent(c, CF=CF, camp_w=camp_w, approach=0, ramp=0, XA=XA, XB=XB,
                    gaps=gaps, kinds=kinds, top_floor=TOPF)
    f0 = CF - 1
    people_at_camp(c, CF, [(2, "T"), (5, "F"), (8, "l"), (10, "m"), (12, "P"), (20, "T")])
    c.sign(17, f0)                                   # sign 0: Barafu
    c.walk_cells(12, XA - 1, f0)
    c.gear["rope"] = (camp_w + 6, f0)
    for b, frac, n in p["ice"]:
        x0 = XA + int((XB - XA) * frac)
        ice(c, x0, x0 + n - 1, floors[b])
        if b == p["ice"][0][0]:
            c.gear["crampons"] = ((x0 - 6) if b % 2 == 0 else (x0 + n + 6), floors[b] - 1)
    if p["crevasse"]:
        b, frac = p["crevasse"]
        x = XA + int((XB - XA) * frac)
        # A crevasse: deep enough that a fall into it is a fall (back to the
        # cairn), with a band of rock over it to cross on.
        c.fill(x, floors[b], x + 1, floors[b] + 5, ".")
        c.fill(x - 2, floors[b] - 4, x + 3, floors[b] - 1, "C")
        for xx in range(x - 1, x + 3):
            c.danger.append((xx, floors[b] - 1, 5))
    jb = p["jun"]
    for i in range(len(kinds)):
        bench_walk(c, i, floors, XA, XB)
        right = i % 2 == 0
        if i == 1:
            c.sign((XB - 10) if right else (XA + 10), floors[1] - 1)   # sign 1: the switchbacks
            c.gear["headlamp"] = ((XB - 16) if right else (XA + 16), floors[1] - 1)
        if i == jb:
            mx = XA + (XB - XA) // 2 - (6 if right else -6)
            c.put(mx, floors[i] - 1, "M")
            c.put(mx - 4 if right else mx + 4, floors[i] - 1, "R")
            # A boulder a few steps past him: you walk on slower with him.
            c.put(mx + 5 if right else mx - 5, floors[i] - 1, "#")
            c.mate = {"cell": [mx, floors[i] - 1], "passDir": 1 if right else -1}
            c.say("walk", (mx - 7.5) if right else (mx + 8.5))
            c.say("mate", {"dir": 1 if right else -1, "choice": "help"})
            c.say("rest", 0.98)
        if i + 1 == len(kinds):
            c.gear["helmet"] = ((XB - 8) if right else (XA + 8), floors[i] - 1)
        climb_step(c, i, floors, XA, XB, chute=i in p["chutes"], kind=kinds[i], then=1 if i + 1 == len(kinds) else None)
    for b in p["water"]:
        put_on_ground(c, XA + (XB - XA) // 2 + 9, floors[b] - 1, "w")
    for b in p["rests"]:
        c.put((XB - 10) if b % 2 == 0 else (XA + 10), floors[b] - 1, "R")
    # The crater rim (the top bench, open sky): saddles in the wind, lee
    # between them with a cairn and a rest stone, slabs in a saddle.
    ft = floors[-1]
    n = len(kinds)
    arrive_right = (n - 1) % 2 == 0
    c.fill(0, ft - 3, XA - 1, ft - 1, "#")
    c.sign((XA + 8) if not arrive_right else (XB - 8), ft - 1)   # sign 2: the rim
    c.gear["shell"] = ((XA + 4) if not arrive_right else (XB - 4), ft - 1)
    span = XB - XA - 20
    k = len(p["saddles"])
    for j, sw in enumerate(p["saddles"]):
        x0 = XA + 14 + (span * (j + 1)) // (k + 1) - sw // 2
        exposed(c, x0, x0 + sw - 1, ft)
        if j < k - 1 or k == 1:
            c.cairn(x0 + sw + 3, ft - 1)
            c.put(x0 + sw + 5, ft - 1, "R")
    for b, frac in p["slabs"]:
        x = XA + int((XB - XA) * frac)
        if b == n and c.get(x, ft - 1) in ".E" and c.get(x + 1, ft - 1) in ".E":
            slab_bridge(c, x, ft)
        elif b < n and all(c.get(xx, floors[b] - 1) == "." for xx in range(x - 1, x + 3)):
            slab_bridge(c, x, floors[b])
    c.put(XA + 10, ft - 1, "w")
    # Stella Point: a last rock step at the east end of the rim.
    fs = ft - p["stella"]
    c.fill(XS, fs, W - 1, ft - 1, "#")
    c.fill(XS, fs, XS + 2, ft - 1, "C")
    c.fill(XS + 3, 0, W - 2, fs - 1, ".")
    c.fill(W - 1, 0, W - 1, c.h - 1, "#")
    c.walk_cells(XA + 3, XS - 1, ft - 1)
    c.walk_cells(XS + 3, W - 4, fs - 1)
    c.say("walk", XS - 3.0)
    c.say("rest", 0.98)
    c.say("climb", {"x": XS + 1.5, "dir": 1, "row": fs, "lean": 1, "chute": False, "niche": None, "kind": "C"})
    c.cairn(XS + 8, fs - 1)
    c.sign(XS + 10, fs - 1)                          # sign 3: Stella Point
    c.put(XS + 14, fs - 1, "V")
    c.put(W - 4, fs - 1, "X")
    c.say("finish", 1)
    return c, floors, {"kindsG": p["kindsG"], "every": p["every"], "wildlife": False}


# --- The way down -----------------------------------------------------------

DESCENT = {
    #          rim length, wind on it, scree ramps (length), rock steps down (height), ice
    "lemosho": {"rim": 32, "wind": [(18, 10)], "ramps": [10, 10], "steps": [5], "ice": 6, "chute": True,
                "slabs": 0, "every": 0},
    "machame": {"rim": 38, "wind": [(18, 18)], "ramps": [12, 12, 12], "steps": [8], "ice": 8, "chute": True,
                "slabs": 1, "every": 9},
    "umbwe":   {"rim": 46, "wind": [(16, 12), (32, 10)], "ramps": [12, 14, 12, 12], "steps": [8, 10], "ice": 12,
                "chute": True, "slabs": 2, "every": 7},
}


def descent(route):
    """From Stella Point along the rim, down scree ramps, rock steps climbed
    down and an icy bench, to Barafu: a profile read left to right, top to
    bottom. Jun sits on the rim."""
    p = DESCENT[route]
    RIM = 14
    segs = []                      # (kind, length/height)
    segs.append(("flat", p["rim"]))
    ramps = list(p["ramps"])
    steps = list(p["steps"])
    # Ramp, bench, (step, bench), ramp, bench ... until both are used.
    while ramps or steps:
        if ramps:
            segs.append(("ramp", ramps.pop(0)))
            segs.append(("flat", 12))
        if steps:
            segs.append(("step", steps.pop(0)))
            segs.append(("flat", 12))
    segs.append(("flat", 30))       # Barafu
    W = 4 + sum(n for k, n in segs if k != "step") + 3 * len(p["steps"]) + 6
    drop = sum(n for k, n in segs if k in ("ramp", "step"))
    H = RIM + drop + 10
    c = Course(W, H, seed=hash(("descent", route)) & 0xffff)
    c.fill(0, 0, W - 1, H - 1, ".")
    top = [RIM] * W
    x, y = 4, RIM
    for xx in range(0, 4):
        top[xx] = 4
    cells = []                     # (kind, x0, x1, y) for each piece
    for kind, n in segs:
        if kind == "flat":
            for k in range(n):
                top[x + k] = y
            cells.append(("flat", x, x + n - 1, y))
            x += n
        elif kind == "ramp":
            for k in range(n):
                top[x + k] = y + k
            cells.append(("ramp", x, x + n - 1, y))
            x += n
            y += n
        elif kind == "step":
            for k in range(3):
                top[x + k] = y            # the face continues the bench's top
            cells.append(("step", x, x + 2, y, n))
            x += 3
            y += n
    for xx in range(x, W):
        top[xx] = y
    for xx in range(W):
        c.fill(xx, top[xx], xx, H - 1, "#")
    c.fill(W - 1, 0, W - 1, H - 1, "#")
    c.fill(0, 0, 0, H - 1, "#")
    ramp_i = 0
    step_seen = 0
    bench_after_step = []
    for piece in cells:
        if piece[0] == "ramp":
            _, x0, x1, y0 = piece
            for k in range(x1 - x0 + 1):
                c.put(x0 + k, y0 + k, "\\")
            c.walk_cells(x0, x1, y0 - 1)
            ramp_i += 1
            if ramp_i == 1:
                c.gear["poles"] = (x0 - 3, y0 - 1)
        elif piece[0] == "step":
            _, x0, x1, y0, hgt = piece
            c.fill(x0, y0, x1, y0 + hgt - 1, "C")
            c.fill(x1 + 1, y0, x1 + 12, y0 + hgt - 1, ".")
            step_seen += 1
            c.danger.append((x0 - 1, y0 - 1, 4))
        else:
            _, x0, x1, y0 = piece
            c.walk_cells(x0, x1, y0 - 1)
            bench_after_step.append((x0, x1, y0))
    # The rim: Stella Point, Lena, Jun; the wind along it.
    c.put(6, RIM - 1, "P")
    c.sign(8, RIM - 1)                               # sign 0: Stella Point
    c.put(10, RIM - 1, "V")
    c.put(13, RIM - 1, "l")
    c.put(16, RIM - 1, "M")
    c.mate = {"cell": [16, RIM - 1], "passDir": 1}
    c.gear["shell"] = (19, RIM - 1)
    c.say("mate", {"dir": 1, "choice": "help"})
    for x0, n in p["wind"]:
        exposed(c, 4 + x0, 4 + x0 + n - 1, RIM)
    c.cairn(4 + p["rim"] - 3, RIM - 1)
    # Each piece: cairns on the benches, ice before the last step, the steps
    # climbed down, a chute, slabs.
    benches = bench_after_step[1:]       # after the rim
    steps_cells = [pc for pc in cells if pc[0] == "step"]
    halfway = None
    for j, (x0, x1, y0) in enumerate(benches[:-1]):
        c.cairn(x0 + 3, y0 - 1)
        if j == len(benches) // 2 - 1 and halfway is None:
            halfway = (x0 + 6, y0 - 1)
            c.put(x0 + 5, y0 - 1, "R")
    c.sign(*halfway)                                 # sign 1: halfway down
    # Ice on the bench above the last step.
    last_step = steps_cells[-1]
    sx0, sy0 = last_step[1], last_step[3]
    above = [b for b in bench_after_step if b[2] == sy0 and b[1] == sx0 - 1]
    if above:
        bx0, bx1, by = above[0]
        ice(c, max(bx0 + 1, bx1 - p["ice"] - 1), bx1 - 2, by)
        c.gear["crampons"] = (bx0 + 1, by - 1)
    # Below the last step: a rest and sign 2.
    below = [b for b in bench_after_step if b[0] == last_step[2] + 1]
    if below:
        bx0, bx1, by = below[0]
        c.put(bx0 + 5, by - 1, "R")
        c.sign(bx0 + 7, by - 1)                      # sign 2: below the step
    if p["chute"]:
        # Stones down the middle of a ramp (the hard way: two ramps).
        ramps_cells = [pc for pc in cells if pc[0] == "ramp"]
        for mid in ramps_cells[1:2] + (ramps_cells[2:3] if route == "umbwe" else []):
            mx = (mid[1] + mid[2]) // 2
            c.put(mx, mid[3] + (mx - mid[1]) - 8, "r")
            c.danger.append((mx, mid[3] + (mx - mid[1]) - 1, 4))
    flats = [b for b in benches[:-1]]
    for k in range(p["slabs"]):
        x0, x1, y0 = flats[min(len(flats) - 1, 1 + k)]
        sx = x0 + (x1 - x0) // 2
        if c.get(sx, y0 - 1) == "." and c.get(sx + 1, y0 - 1) == ".":
            slab_bridge(c, sx, y0)
    # Barafu.
    bx0, bx1, by = bench_after_step[-1]
    c.cairn(bx0 + 4, by - 1)
    c.sign(bx0 + 8, by - 1)                          # sign 3: Barafu
    for xx in (bx0 + 12, bx0 + 20):
        c.put(xx, by - 1, "T")
    c.put(bx0 + 16, by - 1, "F")
    c.put(bx0 + 18, by - 1, "m")
    c.put(min(W - 3, bx0 + 26), by - 1, "X")
    # The line: along the rim in the wind, down each ramp, each step.
    for piece in cells:
        if piece[0] == "step":
            _, x0, x1, y0, hgt = piece
            c.say("walk", x0 - 0.7)
            c.say("rest", 0.95)
            c.say("down", {"dir": 1, "row": y0 + hgt})
        elif piece[0] == "ramp":
            pass
    c.say("finish", 1)
    # Walk segments between are covered by "down" approach walks and finish.
    return c, None, {"kindsG": ("hop", "pit", "slabs", "ice", "hop"), "every": p["every"], "wildlife": False}


# --- Writing ---------------------------------------------------------------

BUILD = {"lava_tower": lava_tower, "barranco": barranco, "summit_night": summit_night, "descent": descent}
GEAR_ORDER = {
    "lava_tower": ["rope", "shell", "helmet", "gloves", "poles"],
    "barranco": ["rope", "gloves", "helmet", "shell", "poles"],
    "summit_night": ["rope", "crampons", "headlamp", "helmet", "shell"],
    "descent": ["shell", "poles", "crampons"],
}


def artifacts(c, n=2, spread=24):
    """The line's most dangerous standing spots: near exposure, slabs,
    voids, ice, stonefall, wildlife. Two, well apart."""
    on_line = {(x, y) for x, y in c.path}
    score = {}
    for x, y, wgt in c.danger:
        for dx in range(-4, 5):
            cell = (x + dx, y)
            if cell in on_line:
                score[cell] = score.get(cell, 0) + wgt * (5 - abs(dx))
    for (x, y) in on_line:
        for yy in range(y - 4, y + 3):
            for xx in range(x - 4, x + 5):
                ch = c.get(xx, yy)
                if ch in "nav":
                    score[(x, y)] = score.get((x, y), 0) + 3
                elif ch == "r" or (ch in "rb" and yy < y):
                    score[(x, y)] = score.get((x, y), 0) + 4
    ok = []
    for (x, y), s in score.items():
        here, below, above = c.get(x, y), c.get(x, y + 1), c.get(x, y - 1)
        if here not in ".E" or below not in SOLID or above not in ".E":
            continue
        if any(c.get(xx, yy) in MARKERS | set("CLsc") for yy in (y - 1, y) for xx in range(x - 2, x + 3)):
            continue
        ok.append((s, x, y))
    ok.sort(reverse=True)
    out = []
    for s, x, y in ok:
        if all(abs(x - a) + abs(y - b) >= spread for a, b in out):
            out.append((x, y))
        if len(out) == n:
            break
    assert len(out) == n, ("not enough artifact spots", len(ok))
    return [list(a) for a in out]


def thin_wildlife(c):
    """One creature per stretch: nothing within eight tiles of another on the
    same stretch of the walk (a raven circles three rows up), as the
    wildlife test asks. Walks the line in order and keeps the first."""
    kept = []
    for y in range(c.h):
        for x in range(c.w):
            if c.g[y][x] in "nav":
                if any(abs(x - kx) < 8 and abs(y - ky) <= 4 for kx, ky in kept):
                    c.g[y][x] = "."
                else:
                    kept.append((x, y))


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


def build(name, route):
    c, floors, g = BUILD[name](route)
    if g["every"]:
        gauntlet(c.g, every=g["every"], kinds=g["kindsG"], raven_max=12)
        if g["wildlife"]:
            wildlife(c.g, every=max(4, g["every"] - 2), kinds=("ants", "plant"))
        thin_wildlife(c)
    clear_before_exit(c)
    # Gear on standable ground near where it helps, in the spec's order.
    order = GEAR_ORDER[name]
    gear = []
    for kind in order:
        try:
            cell = place_near(c.g, [c.gear[kind]])[0]
        except AssertionError:
            # Nothing clear right there: the nearest clear spot on the line.
            tx, ty = c.gear[kind]
            best = None
            for x, y in c.path:
                if (c.get(x, y) == "." and c.get(x, y + 1) in "#/\\i" and c.get(x, y - 1) in ".E"
                        and not any(c.get(xx, yy) in MARKERS | set("CLsc") for yy in range(y - 1, y + 2) for xx in range(x - 2, x + 3))):
                    d = abs(x - tx) + 3 * abs(y - ty)
                    if best is None or d < best[0]:
                        best = (d, x, y)
            assert best is not None, (name, route, "no ground for", kind)
            cell = (best[1], best[2])
            c.g[cell[1]][cell[0]] = "*"
        gear.append(list(cell))
    arts = artifacts(c)
    side = {
        "route": route,
        "cairns": c.cairns,
        "signs": c.signs,
        "gear": gear,
        "artifacts": arts,
        "mate": c.mate,
        "script": c.script,
    }
    return c, side


def check(name, route, c, side):
    """What every climb needs, and fair play: things stand on ground."""
    g = c.g
    count = lambda ch: sum(row.count(ch) for row in g)
    assert count("P") == 1 and count("X") == 1, (name, route, "start and exit")
    assert count("K") == len(side["cairns"]) >= 4, (name, route, "cairns", count("K"), len(side["cairns"]))
    assert count("S") == len(side["signs"]), (name, route, "signs")
    assert count("*") == len(side["gear"]), (name, route, "gear")
    assert count("r") >= 1, (name, route, "stonefall")
    for x, y in side["gear"] + side["artifacts"]:
        assert g[y][x] in ".E*" and g[y + 1][x] in SOLID, (name, route, "on ground", x, y, g[y][x], g[y + 1][x])


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
    img.resize((c.w * 5, c.h * 5), Image.NEAREST).save(path)


def main():
    out_dir = None
    if "--preview" in sys.argv:
        out_dir = Path(sys.argv[sys.argv.index("--preview") + 1])
        out_dir.mkdir(parents=True, exist_ok=True)
    for name in BUILD:
        for route in ROUTES:
            c, side = build(name, route)
            # Gear markers go in last, where the placement said.
            for x, y in side["gear"]:
                c.g[y][x] = "*"
            check(name, route, c, side)
            base = LEVELS / name / f"{name}_{route}"
            base.with_suffix(".txt").write_text(c.text())
            base.with_suffix(".json").write_text(json.dumps(side, indent=1) + "\n")
            print(f"{name:13} {route:8} {c.w}x{c.h}  cairns {len(side['cairns'])}  steps {sum(1 for a in side['script'] if a[0] in ('climb', 'down'))}")
            if out_dir:
                preview(c, out_dir / f"{name}_{route}.png")


if __name__ == "__main__":
    main()
