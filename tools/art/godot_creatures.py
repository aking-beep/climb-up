"""
Pixel art for the climbs' dangerous plants and animals, in the style of the
Godot props (one texel per world pixel, dark outlines):

  godot/assets/terrain/props/thistle.png  2 x (16 x 16): the Kilimanjaro
                                          thistle (spiny, purple head), and
                                          a stinging nettle (Barranco's
                                          lush valley)
  godot/assets/terrain/props/ants.png     3 x (24 x 6): a marching column of
                                          siafu (safari ants), walk frames
  godot/assets/terrain/props/raven.png    2 x (18 x 12): a white-necked
                                          raven, wings up and down, facing
                                          right

    python3 tools/art/godot_creatures.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "godot" / "assets" / "terrain" / "props"


def rgb(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def paint(rows, palette):
    h, w = len(rows), max(len(r) for r in rows)
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette:
                px[x, y] = palette[ch]
    return im


THISTLE = [
    "................",
    "......p.p.......",
    ".....pPpPp......",
    "....oPpPpPo.....",
    "....oPPPPPo.....",
    ".....oGGGo......",
    "...s..oGo..s....",
    "..sgs..g..sgs...",
    "...gGs.g.sGg....",
    ".s..gGsgsGg..s..",
    "sgs..gGgGg..sgs.",
    ".gGs..gGg..sGg..",
    "..gGs.gGg.sGg...",
    "...gGsgGgsGg....",
    "....gGgGgGg.....",
    ".....gGgGg......",
]

NETTLE = [
    "................",
    ".......g........",
    "......gGg.......",
    ".....gGLGg......",
    "......gGg.......",
    "...g...g...g....",
    "..gGg..g..gGg...",
    ".gGLGg.g.gGLGg..",
    "..gGGg.g.gGGg...",
    "...gg..g..gg....",
    ".......g........",
    "..gGg..g..gGg...",
    ".gGLGgsgsgGLGg..",
    "..gGGg.g.gGGg...",
    "...gg..g..gg....",
    ".......g........",
]

ANT = ["o.o.", "AaAa", "o.o."]
ANT_B = [".o.o", "AaAa", ".o.o"]

RAVEN_UP = [
    "......oo..........",
    ".....oKKo.........",
    "....oKKKKo........",
    "...oKKKKKKo.......",
    "......oKKKKo......",
    ".......oKKWKoo....",
    "..oooooKKKWWKKY...",
    ".oKKKKKKKKKKKoo...",
    "..oooKKKKKKKo.....",
    ".....ooKKKoo......",
    ".......o.o........",
    "..................",
]

RAVEN_DOWN = [
    "..................",
    "..................",
    "..................",
    "..................",
    "..................",
    ".......oKKWKoo....",
    "..oooooKKKWWKKY...",
    ".oKKKKKKKKKKKoo...",
    "..oooKKKKKKKKo....",
    "....oKKKKKKo......",
    "...oKKKKKo........",
    "....oooo.o........",
]


def main():
    pal = {
        "o": rgb("#1c1714"), "p": rgb("#c58ad6"), "P": rgb("#8e4fa6"),
        "g": rgb("#3f6b3a"), "G": rgb("#6f9a52"), "L": rgb("#a8cf72"),
        "s": rgb("#e8e0c8"),
    }
    sheet = Image.new("RGBA", (32, 16))
    sheet.paste(paint(THISTLE, pal), (0, 0))
    sheet.paste(paint(NETTLE, pal), (16, 0))
    sheet.save(PROPS / "thistle.png")

    ant_pal = {"o": rgb("#2a1410"), "A": rgb("#8a3a22"), "a": rgb("#5a2416")}
    ants = Image.new("RGBA", (72, 6))
    for f in range(3):
        frame = Image.new("RGBA", (24, 6))
        for k in range(5):
            shape = ANT if (k + f) % 2 == 0 else ANT_B
            frame.paste(paint(shape, ant_pal), (k * 5 + (f % 2), 2 if (k + f) % 3 else 1))
        ants.paste(frame, (f * 24, 0))
    ants.save(PROPS / "ants.png")

    raven_pal = {"o": rgb("#0e0c0c"), "K": rgb("#2b2830"), "W": rgb("#efeae0"), "Y": rgb("#3a3330")}
    raven = Image.new("RGBA", (36, 12))
    raven.paste(paint(RAVEN_UP, raven_pal), (0, 0))
    raven.paste(paint(RAVEN_DOWN, raven_pal), (18, 0))
    raven.save(PROPS / "raven.png")
    print("wrote thistle.png, ants.png, raven.png")


if __name__ == "__main__":
    main()
