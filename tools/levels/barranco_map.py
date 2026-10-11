"""
The Godot Barranco Wall level, stamped as an ASCII map. Writes
godot/modes/expedition/levels/kilimanjaro/barranco/barranco.txt (the level)
and, with --preview <png>, a picture of it.

Legend (one character per 16 px tile):
  #  basalt (solid)            /  slope rising right    \\  slope rising left
  C  climbable face            L  loose scree face      s  scramble boulders
  E  exposed ground (wind)     R  rest stone            K  cairn (checkpoint)
  P  start   X  exit   M  Marco   l Lena  j Jun  p porter
  S  sign    T  tent   F  fire    g groundsel   o lobelia   V  vista
  .  air (inside the mountain it shows the back wall)

    python3 tools/levels/barranco_map.py [--preview out.png]
"""

import sys
from pathlib import Path

W, H = 228, 98
OY = 14  # the lower wall was drawn first; everything below is shifted down by this
OUT = Path(__file__).resolve().parents[2] / "godot" / "modes" / "expedition" / "levels" / "kilimanjaro" / "barranco" / "barranco.txt"

g = [["." for _ in range(W)] for _ in range(H)]


def fill(x0, y0, x1, y1, ch, absolute=False):
    oy = 0 if absolute else OY
    for y in range(y0 + oy, min(H - 1, y1 + oy) + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = ch


def put(x, y, ch, absolute=False):
    g[y + (0 if absolute else OY)][x] = ch


# Ground under the camp, and the left edge of the valley.
fill(0, 78, 35, H - 1, "#")
fill(0, 62, 1, 77, "#")
# Approach: a slope up to the wall foot, then level under the buttress.
for i in range(10):
    x, y = 36 + i, 77 - i
    put(x, y, "/")
    fill(x, y + 1, x, H - 1, "#")
fill(46, 68, 59, H - 1, "#")

# The wall: one mass from the foot to the plateau, then carved.
fill(60, 12, 100, H - 1, "#")      # lower wall and plateau base
fill(44, 12, 59, 64, "#")          # upper wall and the buttress over the approach
fill(101, 12, W - 1, H - 1, "#")   # plateau

# 1. Scramble band at the foot (x 60-62), up to ledge 1.
fill(60, 60, 62, 67, "s")
fill(60, 65, 62, 67, "s")
# Ledge 1: rows 57-59, floor row 60, heading right.
fill(60, 57, 84, 59, ".")         # (open over the band, to pull over)
# 2. First face, up from the end of ledge 1 to ledge 2.
fill(85, 46, 87, 59, "C")
# Ledge 2: rows 43-45, floor row 46, heading back left.
fill(63, 43, 87, 45, ".")         # (open over the face, to pull over)
# 3. Narrow traverse over a void: a band of face (x 56-65, rows 42-45).
fill(56, 42, 65, 45, "C")
fill(56, 46, 62, 56, ".")           # the void under it
# Rest ledge at the west end of the traverse: rows 42-44, floor row 45.
fill(48, 42, 55, 44, ".")
# 4. Steeper face up from the rest ledge to ledge 3.
fill(48, 28, 50, 44, "C")
# Ledge 3: rows 25-27, floor row 28, thin over a second void.
fill(48, 25, 83, 27, ".")         # (open over the face, to pull over)
fill(57, 29, 74, 40, ".")
# 5. The loose gully from the east end of ledge 3 to the plateau.
fill(80, 12, 83, 27, "L")
fill(80, 9, 83, 11, ".")
# A niche halfway up the gully to step into and get your breath back.
fill(84, 17, 86, 19, ".")
# The shoulder: where the gully tops out (old row 12), a broad ledge with
# the view back down to camp. Everything from here is in absolute rows.
SH = 12 + OY  # shoulder floor row
fill(105, 0, W - 1, SH - 1, "#", absolute=True)   # the upper wall, above the shoulder
fill(84, 0, 104, SH - 1, ".", absolute=True)
fill(84, SH + 5, 86, SH + 7, ".", absolute=True)  # the gully niche, again
for x in range(80, 84):
    fill(x, 0, x, SH - 4, ".", absolute=True)
# 6. The crouch ledge: under an overhang, open to the wind (x 105-116).
fill(105, SH - 2, 116, SH - 1, ".", absolute=True)
# 7. The upper face from the end of the crouch ledge to the top of the wall.
TOP = SH - 14
fill(117, TOP, 119, SH - 1, "C", absolute=True)
fill(117, TOP - 3, 119, TOP - 1, ".", absolute=True)
# The top: open sky above, a rise to the viewpoint, then down to Karanga.
fill(105, 0, W - 2, TOP - 1, ".", absolute=True)
for i in range(3):
    x, y = 150 + i, TOP - 1 - i
    put(x, y, "/", absolute=True)
    fill(x, y + 1, x, TOP - 1, "#", absolute=True)
fill(153, TOP - 3, 175, TOP - 1, "#", absolute=True)
for i in range(7):
    x, y = 176 + i, TOP - 3 + i
    fill(x, 0, x, y - 1, ".", absolute=True)
    put(x, y, "\\", absolute=True)
    fill(x, y + 1, x, TOP + 4, "#", absolute=True)
fill(183, TOP + 4, W - 2, TOP + 4, "#", absolute=True)
for x in range(183, W - 1):
    fill(x, 0, x, TOP + 3, ".", absolute=True)
fill(W - 1, 0, W - 1, H - 1, "#", absolute=True)

# Rough, geological edges where the player never walks: the wall's west
# face and buttress, the crags along its top, and the sides of the voids.
import random
rnd = random.Random(31)


def smooth_offsets(n, amplitude, step=3):
    pts = [rnd.randint(0, amplitude) for _ in range(n // step + 2)]
    out = []
    for i in range(n):
        a, b = pts[i // step], pts[i // step + 1]
        t = (i % step) / step
        out.append(round(a + (b - a) * t))
    return out


# West face (x 44..) from the top of the wall down the buttress.
west = smooth_offsets(64 - 13 + 1, 3)
for i, y in enumerate(range(13, 65)):
    for k in range(west[i]):
        if g[y + OY][44 + k] == "#":
            g[y + OY][44 + k] = "."
# Crags along the top of the wall, west of the gully.
top = smooth_offsets(79 - 44 + 1, 4, step=2)
for i, x in enumerate(range(44 + 3, 79)):
    for k in range(top[i]):
        g[11 + OY - k][x] = "#"
# Ragged sides and floors for the two voids.
for (x0, x1, y0, y1) in ((56, 62, 48, 56), (57, 74, 31, 40)):
    for y in range(y0, y1 + 1):
        if rnd.random() < 0.5:
            g[y + OY][x0] = "#"
        if rnd.random() < 0.5:
            g[y + OY][x1] = "#"
    for x in range(x0, x1 + 1):
        if rnd.random() < 0.45:
            g[y1 + OY][x] = "#"
# Hanging rock under the thin exposed ledge, so it reads as a lip, not a plank.
for x in range(58, 74):
    if rnd.random() < 0.35:
        g[29 + OY][x] = "#"

# Exposure on ledge 3 (over the void) and on the crouch ledge.
for x in range(57, 75):
    put(x, 27, "E")
for x in range(106, 116):
    put(x, SH - 1, "E", absolute=True)

# Challenges. Stones come down the loose gully (dodge between columns, or
# wait in the niche). Two cracked slabs on the exposed ledge: brace on them
# in a gust and they go.
put(82, 20, "r", absolute=True)
put(66, 28, "c")
put(67, 28, "c")
# Secrets: an alcove above ledge 2, up a short face; the back of the gully
# niche; a ledge on the plateau, up a pinnacle.
fill(77, 38, 82, 40, ".")
fill(77, 41, 79, 45, "C")
put(81, 40, "*")
put(86, SH + 7, "*", absolute=True)
fill(164, TOP - 10, 166, TOP - 4, "C", absolute=True)
fill(167, TOP - 10, 170, TOP - 9, "#", absolute=True)
put(169, TOP - 11, "*", absolute=True)
put(51, 44, "w")       # water at the rest ledge
# The walk: a boulder out of camp, a stream cut at the camp's edge, a boulder
# on the shoulder, and on the plateau a boulder, a rolling stone and a crack.
put(27, 77, "#")
fill(33, 78, 34, 86, ".")
put(101, SH - 1, "#", absolute=True)
put(134, TOP - 1, "#", absolute=True)
put(196, TOP + 3, "b", absolute=True)
fill(205, TOP + 4, 206, TOP + 12, ".", absolute=True)
fill(157, TOP - 3, 158, TOP + 4, ".", absolute=True)
put(188, TOP + 3, "#", absolute=True)
put(214, TOP + 3, "#", absolute=True)
put(94, SH - 1, "w", absolute=True)

# People, places, things.
put(4, 77, "p")
put(7, 77, "T")
put(10, 77, "F")
put(13, 77, "T")
put(17, 77, "l")
put(20, 77, "j")
put(24, 77, "P")
put(29, 77, "o")
put(31, 77, "S")       # sign 0: Barranco Camp
put(2, 77, "g")
put(56, 67, "K")       # cairn 1, at the wall foot
put(53, 67, "S")       # sign 1: the wall
put(70, 59, "g") if False else None
put(53, 44, "K")       # cairn 2, rest ledge
put(54, 44, "R")
put(52, 27, "K")       # cairn 3, before the exposed ledge
put(54, 27, "S")       # sign 2: wind
put(77, 27, "M")       # Marco
put(76, 27, "K")       # cairn 4, Marco's ledge
put(92, SH - 1, "V", absolute=True)      # the view back down to camp
put(96, SH - 1, "K", absolute=True)      # cairn 5, the shoulder
put(98, SH - 1, "S", absolute=True)      # sign 3: the shoulder
put(88, SH - 1, "g", absolute=True)
put(121, TOP - 1, "K", absolute=True)    # cairn 6, top of the wall
put(124, TOP - 1, "S", absolute=True)    # sign 4: top of the wall
put(160, TOP - 4, "V", absolute=True)    # the view from the rise
put(130, TOP - 1, "g", absolute=True)
put(138, TOP - 1, "o", absolute=True)
put(145, TOP - 1, "g", absolute=True)
put(165, TOP - 4, "g", absolute=True)
put(192, TOP + 3, "o", absolute=True)
put(200, TOP + 3, "g", absolute=True)
put(210, TOP + 3, "g", absolute=True)
put(222, TOP + 3, "X", absolute=True)


def main():
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from flowers import sprinkle
    print("everlastings:", sprinkle(g))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join("".join(row) for row in g) + "\n")
    print("wrote", OUT, f"{W}x{H}")
    if "--preview" in sys.argv:
        from PIL import Image
        colours = {
            "#": (70, 60, 52), "/": (90, 78, 66), "\\": (90, 78, 66), "C": (140, 120, 100), "L": (170, 140, 110),
            "s": (150, 130, 110), "E": (200, 120, 120), ".": (150, 180, 205), "K": (240, 220, 80), "R": (90, 160, 90),
            "P": (60, 200, 60), "X": (220, 60, 60), "M": (230, 110, 50), "S": (200, 160, 90),
            "c": (120, 60, 160), "r": (255, 0, 0), "w": (0, 90, 255), "*": (255, 255, 0), "b": (255, 120, 0),
        }
        img = Image.new("RGB", (W, H))
        px = img.load()
        for y in range(H):
            for x in range(W):
                px[x, y] = colours.get(g[y][x], (255, 255, 255))
        img.resize((W * 6, H * 6), Image.NEAREST).save(sys.argv[sys.argv.index("--preview") + 1])


if __name__ == "__main__":
    main()
