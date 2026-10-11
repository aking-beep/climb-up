"""
Pixel art for the crag: holds drawn over face tiles, the bolts you clip,
and the anchor at the top. Same style as the Godot props (one texel per
world pixel, dark outlines).

  godot/assets/crag/holds.png      2 x (16 x 16): crimps (thin chalked
                                    edges), a jug (a big incut hold)
  godot/assets/crag/quickdraw.png  2 x (8 x 14): a bolt with a quickdraw,
                                    unclipped and clipped (rope through)
  godot/assets/crag/anchor.png     12 x 12: two bolts and a chain at the top
  godot/assets/crag/jug.png        14 x 8: a jug, a big incut hold with
                                    chalk on its lip and a shadow under it

    python3 tools/art/godot_crag.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "assets" / "crag"


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


CRIMPS = [
    "................",
    "..ooooo.........",
    "..wwwww.........",
    "...www..........",
    "................",
    ".........oooo...",
    ".........wwww...",
    "..........ww....",
    "................",
    "...oooo.........",
    "...wwww.........",
    "....w...........",
    "................",
    "..........oooo..",
    "..........wwww..",
    "................",
]

JUG = [
    "................",
    "................",
    "...oooooooooo...",
    "..oHHHHHHHHHHo..",
    "..oHhhhhhhhhHo..",
    "..oHh......hHo..",
    "...oh......ho...",
    "....o......o....",
    "................",
    ".....oooooo.....",
    "....oHHHHHHo....",
    "....oHhhhhHo....",
    ".....o....o.....",
    "................",
    "................",
    "................",
]

DRAW = [
    "..oo....",
    ".oMMo...",
    ".oMMo...",
    "..oo....",
    "...B....",
    "...B....",
    "...B....",
    "...B....",
    "..ooo...",
    ".oM.Mo..",
    ".oM.Mo..",
    ".oM.Mo..",
    "..ooo...",
    "........",
]

DRAW_CLIPPED = [
    "..oo....",
    ".oMMo...",
    ".oMMo...",
    "..oo....",
    "...B....",
    "...B....",
    "...B....",
    "...B....",
    "..ooo...",
    ".oMRMo..",
    "RRRRRRRR",
    ".oM.Mo..",
    "..ooo...",
    "........",
]

ANCHOR = [
    "..oo....oo..",
    ".oMMo..oMMo.",
    ".oMMo..oMMo.",
    "..oo....oo..",
    "...M....M...",
    "....M..M....",
    ".....MM.....",
    ".....oo.....",
    "....oMMo....",
    "....oMMo....",
    ".....oo.....",
    "............",
]


BIG_JUG = [
    "...oooooooo...",
    ".ooccccccccoo.",
    "oHhcccccccchHo",
    "oHhhhhhhhhhhHo",
    "oHDSSSSSSSSDHo",
    ".oHDSSSSSSDHo.",
    "..ooHHHHHHoo..",
    "....oooooo....",
]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pal = {
        "o": rgb("#2a1d16"), "w": rgb("#f4f1ea", 230),
        "H": rgb("#8a5a3e"), "h": rgb("#b98762"),
        "M": rgb("#c9ccd2"), "B": rgb("#3b6fa8"), "R": rgb("#e0663c"),
    }
    holds = Image.new("RGBA", (32, 16))
    holds.paste(paint(CRIMPS, pal), (0, 0))
    holds.paste(paint(JUG, pal), (16, 0))
    holds.save(OUT / "holds.png")
    draws = Image.new("RGBA", (16, 14))
    draws.paste(paint(DRAW, pal), (0, 0))
    draws.paste(paint(DRAW_CLIPPED, pal), (8, 0))
    draws.save(OUT / "quickdraw.png")
    paint(ANCHOR, pal).save(OUT / "anchor.png")
    jug_pal = {
        "o": rgb("#2a1d16"), "H": rgb("#a86b45"), "h": rgb("#d39a68"),
        "c": rgb("#f6f2e8"), "D": rgb("#4a2c1c"), "S": rgb("#24150e"),
    }
    paint(BIG_JUG, jug_pal).save(OUT / "jug.png")
    print("wrote holds.png, quickdraw.png, anchor.png, jug.png")


if __name__ == "__main__":
    main()
