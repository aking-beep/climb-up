"""
Gear placed by hand, near a target: each piece goes on standable ground (open
air, solid ground under it, room above) closest to where it makes sense (a
helmet before a stonefall, a rope before the first faces), clear of other
markers. Shared by the level stampers. Returns the cells used, so the
level's spec can name what lies where.
"""

SOLID = set("#/\\i")
MARKERS = set("PXMljmpSTFgoVKrw*bdRfnavcC")


def _standable(g, x, y):
    h, w = len(g), len(g[0])
    if not (1 <= x < w - 1 and 1 <= y < h - 1):
        return False
    if g[y][x] != "." or g[y + 1][x] not in SOLID or g[y - 1][x] not in ".E":
        return False
    return not any(g[yy][xx] in MARKERS for yy in range(y - 1, y + 2) for xx in range(x - 2, x + 3)
                   if 0 <= yy < h and 0 <= xx < w)


def place(g, targets, ch="*"):
    """targets: (x, y) to search near, or (x, y, "exact") for that very cell
    (it must be open with ground under it; nearby markers are allowed).
    `ch` is the marker (gear by default; K for a cairn)."""
    cells = []
    for t in targets:
        tx, ty = t[0], t[1]
        if len(t) > 2 and t[2] == "exact":
            assert g[ty][tx] == "." and g[ty + 1][tx] in SOLID, ("not standable", tx, ty, g[ty][tx], g[ty + 1][tx])
            g[ty][tx] = ch
            cells.append((tx, ty))
            continue
        best = None
        for y in range(ty - 6, ty + 7):
            for x in range(tx - 14, tx + 15):
                if _standable(g, x, y):
                    d = abs(x - tx) + 3 * abs(y - ty)
                    if best is None or d < best[0]:
                        best = (d, x, y)
        assert best is not None, ("no ground for gear near", tx, ty)
        g[best[2]][best[1]] = ch
        cells.append((best[1], best[2]))
    return cells
