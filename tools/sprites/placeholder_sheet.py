"""
PLACEHOLDER sprite sheets for the Barranco graybox.

Programmer art, not production art. Side-view climbers drawn from a tiny
joint skeleton so every animation state has genuine, distinct frames. The
palette follows the existing front-facing party sprites (assets/world/
pixel-*.png). Replace with hand-drawn Aseprite sheets using the same frame
size and frame order; see docs/asset-manifest.md.

    python3 tools/sprites/placeholder_sheet.py

Writes assets/hd2d/characters/{you,marco}-placeholder.png:
16x24 frames, 8 columns. Frame order must match
src/features/climbing/sprites.ts.
"""

from pathlib import Path

from PIL import Image, ImageDraw

W, H, COLS = 16, 24, 8
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "hd2d" / "characters"

OUTLINE = (27, 22, 26, 255)
SKIN = (240, 208, 144, 255)
HAT = (224, 222, 208, 255)
HAIR = (96, 48, 16, 255)
PANTS = (80, 64, 48, 255)
BOOT = (96, 48, 16, 255)
PACK = (112, 80, 40, 255)

PARTY = {
    "you": {"jacket": (96, 104, 48, 255), "shade": (64, 72, 32, 255)},
    "marco": {"jacket": (192, 64, 16, 255), "shade": (128, 32, 0, 255)},
}


def frame(hip, lean=0, arms=((2, 5), (-1, 5)), legs=((2, 0), (-2, 0)), knees=None, head_tilt=0, pack=True):
    """
    hip: (x, y) of the hip in the 16x24 frame (feet are at y=23).
    lean: shoulders shift right by this many pixels.
    arms: hand offsets from the shoulder (front arm, back arm).
    legs: foot offsets from directly below the hip at y=23 (front, back).
    """
    return dict(hip=hip, lean=lean, arms=arms, legs=legs, knees=knees, head_tilt=head_tilt, pack=pack)


# Order matters: indices are referenced by src/features/climbing/sprites.ts.
FRAMES = [
    # 0-1 idle (breathing)
    frame((8, 16)),
    frame((8, 16), arms=((2, 6), (-1, 6))),
    # 2-5 walk
    frame((8, 16), lean=1, arms=((3, 4), (-2, 5)), legs=((3, 0), (-3, 0))),
    frame((8, 15), lean=1, arms=((1, 6), (0, 6)), legs=((1, 0), (-1, -1))),
    frame((8, 16), lean=1, arms=((-2, 5), (3, 4)), legs=((-3, 0), (3, 0))),
    frame((8, 15), lean=1, arms=((0, 6), (1, 6)), legs=((-1, -1), (1, 0))),
    # 6-9 climb (facing the rock on the right, hands up)
    frame((7, 16), lean=1, arms=((4, -5), (3, -1)), legs=((3, -3), (1, 0)), pack=True),
    frame((7, 15), lean=1, arms=((4, -3), (3, -5)), legs=((2, -1), (2, -3))),
    frame((7, 16), lean=1, arms=((3, -1), (4, -5)), legs=((1, 0), (3, -3))),
    frame((7, 15), lean=1, arms=((3, -5), (4, -3)), legs=((2, -3), (2, -1))),
    # 10-11 hang (both hands high, small sway)
    frame((7, 16), lean=1, arms=((4, -5), (3, -5)), legs=((2, -1), (1, 0))),
    frame((7, 16), lean=0, arms=((4, -5), (3, -4)), legs=((1, 0), (2, -1))),
    # 12-13 fall
    frame((8, 14), lean=-1, arms=((3, -4), (-3, -3)), legs=((3, -2), (-2, -1))),
    frame((8, 14), lean=-1, arms=((-3, -4), (3, -3)), legs=((-2, -2), (3, -1))),
    # 14-15 slip (crumpled)
    frame((8, 18), lean=2, arms=((4, 2), (-2, 3)), legs=((4, 0), (-3, 0)), head_tilt=1),
    frame((8, 19), lean=3, arms=((4, 3), (0, 3)), legs=((4, 0), (-4, 0)), head_tilt=1),
    # 16-17 rest (kneeling, breathing)
    frame((8, 19), lean=1, arms=((3, 3), (1, 4)), legs=((3, 0), (-3, 0)), knees=((3, -2), None)),
    frame((8, 19), lean=1, arms=((3, 4), (1, 4)), legs=((3, 0), (-3, 0)), knees=((3, -2), None)),
    # 18 brace (low, hand on the rock)
    frame((7, 18), lean=2, arms=((5, 4), (4, 2)), legs=((3, 0), (-3, 0))),
    # 19-20 help (kneeling, reaching down and forward)
    frame((7, 19), lean=2, arms=((6, 4), (5, 3)), legs=((3, 0), (-3, 0)), knees=((3, -2), None)),
    frame((7, 19), lean=1, arms=((5, 1), (4, 0)), legs=((3, 0), (-3, 0)), knees=((3, -2), None)),
    # 21-22 celebrate
    frame((8, 16), arms=((2, -6), (-2, -6)), legs=((2, 0), (-2, 0))),
    frame((8, 15), arms=((3, -7), (-3, -6)), legs=((2, -1), (-2, -1))),
    # 23-26 tired walk (hunched, short steps)
    frame((8, 17), lean=2, arms=((3, 5), (0, 6)), legs=((2, 0), (-2, 0)), head_tilt=1),
    frame((8, 17), lean=2, arms=((2, 6), (1, 6)), legs=((1, 0), (-1, 0)), head_tilt=1),
    frame((8, 17), lean=2, arms=((0, 6), (3, 5)), legs=((-2, 0), (2, 0)), head_tilt=1),
    frame((8, 17), lean=2, arms=((1, 6), (2, 6)), legs=((-1, 0), (1, 0)), head_tilt=1),
]


def draw(d: ImageDraw.ImageDraw, ox: int, oy: int, f: dict, jacket, shade):
    hx, hy = f["hip"]
    sx, sy = hx + f["lean"], hy - 6
    # Back leg and back arm first, so the front limbs sit on top.
    for i in (1, 0):
        fx, fy = f["legs"][i]
        foot = (hx + fx, 23 + fy)
        knee = f["knees"][i] if f["knees"] and f["knees"][i] else None
        if knee:
            mid = (hx + knee[0], hy + 4 + knee[1])
            d.line([(ox + hx, oy + hy), (ox + mid[0], oy + mid[1]), (ox + foot[0], oy + foot[1])], fill=PANTS, width=2)
        else:
            d.line([(ox + hx, oy + hy), (ox + foot[0], oy + foot[1])], fill=PANTS, width=2)
        d.rectangle([ox + foot[0], oy + foot[1] - 1, ox + foot[0] + 1, oy + foot[1]], fill=BOOT)
        if i == 1:
            ax, ay = f["arms"][1]
            d.line([(ox + sx, oy + sy + 1), (ox + sx + ax, oy + sy + 1 + ay)], fill=shade, width=1)
    if f["pack"]:
        d.rectangle([ox + sx - 3, oy + sy, ox + sx - 2, oy + sy + 5], fill=PACK)
    # Torso.
    d.polygon(
        [(ox + sx - 1, oy + sy), (ox + sx + 2, oy + sy), (ox + hx + 2, oy + hy), (ox + hx - 1, oy + hy)],
        fill=jacket,
        outline=shade,
    )
    # Head, hat, hair.
    tilt = f["head_tilt"]
    cx, cy = sx + 1 + tilt, sy - 3
    d.rectangle([ox + cx - 1, oy + cy - 1, ox + cx + 2, oy + cy + 2], fill=SKIN)
    d.rectangle([ox + cx - 2, oy + cy - 1, ox + cx - 1, oy + cy + 1], fill=HAIR)
    d.rectangle([ox + cx - 2, oy + cy - 3, ox + cx + 2, oy + cy - 1], fill=HAT)
    d.point((ox + cx + 2, oy + cy), fill=OUTLINE)
    # Front arm last.
    ax, ay = f["arms"][0]
    d.line([(ox + sx + 1, oy + sy + 1), (ox + sx + 1 + ax, oy + sy + 1 + ay)], fill=jacket, width=1)
    d.point((ox + sx + 1 + ax, oy + sy + 1 + ay), fill=SKIN)


def outline(sheet: Image.Image) -> Image.Image:
    """One-pixel dark outline around every opaque pixel, like the party sprites."""
    src = sheet.load()
    out = sheet.copy()
    dst = out.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < sheet.width and 0 <= ny < sheet.height and src[nx, ny][3] != 0 and src[nx, ny] != OUTLINE:
                    if (nx // W) == (x // W) and (ny // H) == (y // H):
                        dst[x, y] = OUTLINE
                        break
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rows = (len(FRAMES) + COLS - 1) // COLS
    for name, colors in PARTY.items():
        sheet = Image.new("RGBA", (W * COLS, H * rows), (0, 0, 0, 0))
        d = ImageDraw.Draw(sheet)
        for index, f in enumerate(FRAMES):
            ox, oy = (index % COLS) * W, (index // COLS) * H
            draw(d, ox, oy, f, colors["jacket"], colors["shade"])
        outline(sheet).save(OUT / f"{name}-placeholder.png")
        print(f"wrote {OUT / f'{name}-placeholder.png'} ({len(FRAMES)} frames)")


if __name__ == "__main__":
    main()
