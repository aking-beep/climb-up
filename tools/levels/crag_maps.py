"""
The crag's routes: one cliff, six lines up it, easiest first. Writes
godot/modes/crag/routes/<id>.txt for the Godot Crag mode.

The grade is how hard the moves are: each route is taller than the one
before, with more stretches of tiny holds (crimps) and fewer big holds
(jugs), spread further apart.

The bolting is set apart from the grade, as on a real cliff: a route can
be easy and run-out, or hard and well bolted. Each route says how many
bolts, how much each gap grows over the one below (`spread`, 0 is even),
and how high the first bolt is (`first`, rows above the foot: a high first
bolt means a fall low down can reach the ground).

Legend (as the expedition maps, plus the crag's own):
  #  rock (the ground, the ledge along the top of the cliff, roofs)
  .  air; below the ledge it is the blank wall of the cliff, unclimbable
  C  the line: rock you can climb
  k  crimps: small holds, they wear the arms out fast, keep moving
  J  a jug: a big hold to hang on and shake the arms out
  Q  a bolt with a quickdraw beside the line (clip it as you pass)
  P  where you start, at the foot of the cliff
  X  the anchor at the top: the route is done

A gap of two rows in a line is blank rock: the only way past is a dyno.

A route is written bottom to top as segments:
  ("up", n)                 n rows of ordinary rock
  ("crimps", n)             n rows of crimps
  ("jug", n)                n rows of jug (2 is one big hold)
  ("blank", n)              n rows of blank rock: dyno across
  ("traverse", dx, k, roof) a two-row band sideways by dx columns, its
                            middle k columns crimps, rock overhead if roof

    python3 tools/levels/crag_maps.py
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "modes" / "crag" / "routes"
W = 36
WALL_X = 10  # the cliff starts here; left of it is open ground under the sky
LEDGE = 5    # the ledge along the top: rows LEDGE and LEDGE + 1
WIDTH = 3    # a line is three columns wide


def rows_of(segments):
    n = 0
    for s in segments:
        n += 2 if s[0] == "traverse" else s[1]
    return n


class Route:
    def __init__(self, segments, x0, bolts, spread, first=3):
        climb = rows_of(segments)
        self.h = climb + LEDGE + 4
        self.g = [["." for _ in range(W)] for _ in range(self.h)]
        for y in (self.h - 2, self.h - 1):
            for x in range(W):
                self.g[y][x] = "#"
        for y in (LEDGE, LEDGE + 1):
            for x in range(WALL_X, W):
                self.g[y][x] = "#"
        self.g[self.h - 3][4] = "P"
        # Where the line is on each row (its left column), and which rows can
        # take a bolt beside them (ordinary rows of the line, not bands or
        # blank rock).
        self.line_x = {}
        self.boltable = set()
        x, y = x0, self.h - 3
        for seg in segments:
            kind = seg[0]
            if kind == "traverse":
                dx, k, roof = seg[1], seg[2], seg[3]
                lo, hi = min(x, x + dx), max(x, x + dx) + WIDTH - 1
                for yy in (y, y - 1):
                    for xx in range(lo, hi + 1):
                        self.g[yy][xx] = "C"
                mid = (lo + hi) // 2
                for yy in (y, y - 1):
                    for xx in range(mid - k // 2, mid - k // 2 + k):
                        self.g[yy][xx] = "k"
                if roof:
                    # Rock right over the band, one row of air above it so
                    # a head fits, except where the line goes on up.
                    for xx in range(lo, hi + 1):
                        if not (x + dx <= xx < x + dx + WIDTH) and not (x <= xx < x + WIDTH):
                            self.g[y - 3][xx] = "#"
                self.line_x[y] = self.line_x[y - 1] = x + dx
                x += dx
                y -= 2
                continue
            n = seg[1]
            ch = {"up": "C", "crimps": "k", "jug": "J", "blank": "."}[kind]
            for i in range(n):
                for xx in range(x, x + WIDTH):
                    self.g[y][xx] = ch
                self.line_x[y] = x
                if kind in ("up", "crimps", "jug"):
                    self.boltable.add(y)
                y -= 1
        assert y == LEDGE + 1, (y, LEDGE + 1)
        # The line through the ledge to the top, and the anchor beside it.
        for yy in (LEDGE, LEDGE + 1):
            for xx in range(x, x + WIDTH):
                self.g[yy][xx] = "C"
        self.g[LEDGE - 1][x + WIDTH + 2] = "X"
        self._bolts(bolts, spread, first)

    @property
    def foot(self):
        return self.h - 3

    def _bolts(self, count, spread, first):
        """`count` bolts beside the line, the first `first` rows up. Each gap
        is `spread` times the first longer than the one before (0: even)."""
        span = (self.foot - first) - (LEDGE + 4)
        weights = [1.0 + spread * i for i in range(count - 1)]
        total = sum(weights)
        want = [self.foot - first]
        for w in weights:
            want.append(want[-1] - span * w / total)
        placed = []
        for target in want:
            row = None
            for d in (0, 1, -1, 2, -2, 3, -3):
                y = int(round(target)) + d
                if y in self.boltable and all(abs(y - p) >= 3 for p in placed):
                    row = y
                    break
            assert row is not None, target
            x = self.line_x[row]
            side = x + WIDTH if self.g[row][x + WIDTH] == "." else x - 1
            assert self.g[row][side] == ".", (row, side)
            self.g[row][side] = "Q"
            placed.append(row)

    def bolt_gaps(self):
        rows = sorted((y for y, row in enumerate(self.g) if "Q" in row), reverse=True)
        return [rows[i] - rows[i + 1] for i in range(len(rows) - 1)]

    def text(self):
        return "\n".join("".join(r) for r in self.g) + "\n"


ROUTES = {
    # The lesson: one of everything, gently. Rock, a bolt, tiny holds, a big
    # hold, a leap. 3 bolts, even. Well bolted.
    "first-climb": ([
        ("up", 5), ("up", 3), ("crimps", 2), ("up", 2), ("jug", 2), ("blank", 2), ("up", 4),
    ], 14, 3, 0.0, 3),
    # Grade 4: good rock, a short bit of crimps, one big hold. 6 bolts, close and even. Well bolted.
    "warm-up": ([
        ("up", 6), ("crimps", 2), ("up", 4), ("jug", 2), ("up", 6), ("crimps", 2), ("up", 5),
    ], 14, 6, 0.0, 3),
    # 5b: up, crimps, a big hold, the long traverse right, crimps, a big
    # hold near the top. Easy moves but sporty: 4 bolts,
    # the first one high, the gaps long up top.
    "sundown": ([
        ("up", 5), ("crimps", 2), ("up", 4), ("jug", 2), ("up", 3), ("traverse", 9, 3, False),
        ("up", 4), ("crimps", 3), ("up", 5), ("jug", 2), ("up", 5),
    ], 12, 4, 0.5, 6),
    # 6a: four stretches of crimps, the longest last; two big holds. Hard moves, well bolted: 8 bolts, close
    # and even (a clip-up).
    "the-pinch": ([
        ("up", 4), ("crimps", 3), ("up", 4), ("jug", 2), ("up", 3), ("crimps", 4), ("up", 4),
        ("crimps", 3), ("up", 3), ("jug", 2), ("crimps", 5), ("up", 3),
    ], 15, 8, 0.0, 3),
    # 6b: a leap from a big hold across blank rock, five stretches of crimps.
    # 6 bolts, the top ones far apart: sporty.
    "leap-of-faith": ([
        ("up", 4), ("crimps", 3), ("up", 3), ("jug", 2), ("crimps", 4), ("up", 3), ("jug", 2),
        ("blank", 2), ("crimps", 3), ("up", 4), ("crimps", 4), ("up", 3), ("jug", 2), ("up", 2),
        ("crimps", 5), ("up", 3),
    ], 15, 6, 0.45, 4),
    # 6c: crimps, a traverse on crimps under a roof, a big hold, a leap,
    # long crimps to the top. 8 bolts, close: the roof is well bolted.
    "lions-roof": ([
        ("up", 3), ("crimps", 4), ("up", 3), ("jug", 2), ("crimps", 4), ("up", 2),
        ("traverse", 8, 3, True), ("jug", 2), ("blank", 2), ("crimps", 4), ("up", 3),
        ("crimps", 4), ("up", 2), ("jug", 2), ("crimps", 6), ("up", 3),
    ], 13, 8, 0.1, 3),
    # 7a: the big one. Two leaps, a roof on crimps, seven stretches of
    # crimps, three big holds a long way apart. 5 bolts, the
    # first one high and the last gaps very long: run-out.
    "thunderhead": ([
        ("up", 3), ("crimps", 5), ("up", 2), ("jug", 2), ("crimps", 4), ("up", 2), ("blank", 2),
        ("crimps", 5), ("up", 2), ("jug", 2), ("traverse", 7, 3, True), ("up", 2), ("crimps", 2), ("up", 2),
        ("jug", 2), ("blank", 2), ("crimps", 5), ("up", 2), ("crimps", 5), ("up", 3),
    ], 13, 5, 0.5, 5),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (segments, x0, bolts, spread, first) in ROUTES.items():
        r = Route(segments, x0, bolts, spread, first)
        path = OUT / f"{name}.txt"
        path.write_text(r.text())
        crimps = sum(1 for s in segments if s[0] == "crimps") + sum(1 for s in segments if s[0] == "traverse" and s[2] > 0)
        jugs = sum(1 for s in segments if s[0] == "jug")
        print(f"wrote {path.name}: {W}x{r.h}, {bolts} bolts (gaps {r.bolt_gaps()}), {crimps} crimp stretches, {jugs} jugs")


if __name__ == "__main__":
    main()
