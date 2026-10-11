"""
Lines every walkable stretch of a level with challenges, so that walking is
never just walking: about one every `every` cells (a second or two at a
walk). Shared by the level stampers; runs before the everlastings are
sprinkled.

Each slot takes the next challenge in turn that fits there:
  hop    a boulder on the path ('#'), needs headroom for a hop; on ice, a
         lump of ice ('i')
  pit    a two-wide pit to jump, five deep with rock all round
  slabs  cracked slabs over a pit: keep walking or fall
  ice    a short stretch of ice

Nothing is placed near markers (camp, cairns, signs, people, finds), near
faces you climb or land from, or where it would not be fair.
"""

SOLID = set("#/\\ic")
# Exposed ground (E) is its own challenge: the wind. Leave it be.
OPEN = set(".")
CLIMB = set("CLs")
# Where you start, respawn, finish, meet people or rest: keep obstacles off
# the approach. Signs, views and finds only need their own cell kept clear.
MARKERS = set("PXMljmpTFKR")
SOFT = set("SVw*rbd")
# Rolling stones run along their row: nothing in their lane they would stop
# against or drop into (slabs and ice are fine).
ROLLERS = set("bd")
DECOR = set("go")


def _get(g, x, y):
    if 0 <= y < len(g) and 0 <= x < len(g[0]):
        return g[y][x]
    return "#"


def _near(g, x, y, chars, rx, ry_up, ry_down):
    for yy in range(y - ry_up, y + ry_down + 1):
        for xx in range(x - rx, x + rx + 1):
            if _get(g, xx, yy) in chars:
                return True
    return False


def _headroom(g, x0, x1, y, rows=3):
    """Room to hop: nothing solid over the spot, and nothing solid beside
    it on the path (no two obstacles in a row), and ground all along (no
    hop that lands at the lip of a gap)."""
    above = all(_get(g, xx, yy) not in SOLID for xx in range(x0 + 1, x1) for yy in range(y - rows, y))
    path = all(_get(g, xx, y) not in SOLID for xx in range(x0, x1 + 1))
    floor = all(_get(g, xx, y + 1) in SOLID for xx in range(x0, x1 + 1))
    return above and path and floor


def _pit_ok(g, x, y):
    # Floor cells x, x+1 at row y+1; rock five deep under them and beside them,
    # and something solid under the pit.
    for xx in range(x - 1, x + 3):
        for yy in range(y + 1, y + 6):
            if _get(g, xx, yy) != "#":
                return False
    return all(_get(g, xx, y + 6) in SOLID for xx in (x, x + 1))


def _lanes(g):
    """The cells a rolling stone runs over: from where it starts ('b' rolls
    left, 'd' right) along the ground to the first wall or drop."""
    lanes = set()
    for y, row in enumerate(g):
        for x, ch in enumerate(row):
            if ch not in ROLLERS:
                continue
            step = -1 if ch == "b" else 1
            xx = x
            while _get(g, xx, y) not in SOLID and _get(g, xx, y + 1) in SOLID:
                for dx in range(-3, 4):
                    lanes.add((xx + dx, y))
                xx += step
    return lanes


def gauntlet(g, every=6, kinds=("hop", "pit", "slabs", "hop", "ice", "pit")):
    h, w = len(g), len(g[0])
    lanes = _lanes(g)
    placed = {k: 0 for k in set(kinds)}
    turn = 0
    for y in range(1, h - 1):
        run = 0
        x = 1
        while x < w - 1:
            here, below = g[y][x], _get(g, x, y + 1)
            if here in DECOR:
                run += 1
                x += 1
                continue
            walkable = here in OPEN and below in SOLID and below != "c"
            if not walkable:
                run = 0
                x += 1
                continue
            run += 1
            if run < every:
                x += 1
                continue
            blocked = (_near(g, x, y, MARKERS, 3, 2, 0) or _near(g, x, y, SOFT, 1, 1, 0) or _near(g, x, y, CLIMB, 3, 4, 2)

                       or not _headroom(g, x - 2, x + 3, y))
            if blocked:
                x += 1
                continue
            done = False
            for attempt in range(len(kinds)):
                kind = kinds[(turn + attempt) % len(kinds)]
                if (x, y) in lanes and kind in ("hop", "pit"):
                    continue  # a rolling stone has to get by: only slabs or ice
                if below == "i" and kind != "hop":
                    continue  # on ice, only a lump of ice to hop
                if kind == "hop":
                    g[y][x] = "i" if below == "i" else "#"
                    done = True
                elif kind in ("pit", "slabs") and _pit_ok(g, x, y) and _get(g, x + 1, y) in OPEN and _get(g, x + 2, y + 1) in SOLID:
                    for yy in range(y + 1, y + 6):
                        g[yy][x] = "."
                        g[yy][x + 1] = "."
                    if kind == "slabs":
                        g[y + 1][x] = "c"
                        g[y + 1][x + 1] = "c"
                    done = True
                elif kind == "ice" and not _near(g, x + 3, y, CLIMB, 4, 4, 2) and all(_get(g, xx, y + 1) == "#" and _get(g, xx, y) in OPEN for xx in range(x, x + 4)):
                    for xx in range(x, x + 4):
                        g[y + 1][xx] = "i"
                    done = True
                if done:
                    placed[kind] += 1
                    turn = (turn + attempt + 1) % len(kinds)
                    break
            run = 0
            x += 3
    return placed
