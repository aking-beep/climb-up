"""
Everlastings along a level's walkable ground: a small reward every few steps,
so there is always something just ahead to reach for. Shared by the level
stampers. Places 'f' on open air with ground under it and room above,
every `spacing` walkable cells, away from other markers and hazards, and
never within `gap` tiles of another everlasting (so they are spread along
the whole climb, not bunched where the ground is flat).
"""

# Few and far between: a handful per climb, each a real find (the gear and
# the cairns are what fill the way now).
GAP = 70

SOLID = set("#/\\ic")
OPEN = set(".")
MARKERS = set("PXMljmpSTFgoVKrw*bdRfnav")


def sprinkle(g, spacing=6, skip_rows=(), gap=GAP):
    h, w = len(g), len(g[0])
    count = 0
    placed = []
    for y in range(1, h - 1):
        if y in skip_rows:
            continue
        run = 0
        for x in range(1, w - 1):
            here, below, above = g[y][x], g[y + 1][x], g[y - 1][x]
            walkable = here in OPEN and below in SOLID and above in OPEN | {"E"}
            if not walkable:
                run = 0
                continue
            run += 1
            near = any(g[yy][xx] in MARKERS for yy in (y - 1, y) for xx in (x - 1, x, x + 1))
            far = all((x - px) ** 2 + (y - py) ** 2 >= gap * gap for px, py in placed)
            if run >= spacing // 2 and not near and below != "c" and far:
                g[y][x] = "f"
                placed.append((x, y))
                count += 1
    return count
