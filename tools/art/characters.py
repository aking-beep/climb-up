"""
Side-view party sprites for the climbing scenes: You, Marco, Lena and Jun.
24 x 32 px frames, 8 columns, 27 frames in the order the clip table in
src/features/climbing/sprites.ts expects. Drawn from a small joint skeleton
with three-tone shading (light from the upper left) and a soft outline.

    python3 tools/art/characters.py
"""

from PIL import Image, ImageDraw

from pixel import OUT, hex_rgb, selective_outline

W, H, COLS = 24, 32, 8
GROUND = 31
S = 1.5  # pose table is authored at the old 16 x 24 scale

SKIN = [hex_rgb("#f0c890"), hex_rgb("#d9a46e"), hex_rgb("#b17a4c")]
PANTS = [hex_rgb("#6b5a48"), hex_rgb("#4f4236"), hex_rgb("#3a3028")]
BOOT = [hex_rgb("#8a5530"), hex_rgb("#5e3519"), hex_rgb("#3b2010")]
PACK = [hex_rgb("#9a7a4c"), hex_rgb("#735733"), hex_rgb("#4d3a21")]
GLOVE = [hex_rgb("#4a4440"), hex_rgb("#322e2b")]

PARTY = {
    "you": {"jacket": ("#8a9448", "#66702f", "#454d1d"), "hat": ("#ecebe2", "#c9c6b8"), "hair": "#6a3a18", "trim": "#d8d4c4"},
    "marco": {"jacket": ("#d9572a", "#a83a14", "#6f2208"), "hat": ("#2f3a4a", "#1d2530"), "hair": "#2a1a10", "trim": "#f0c060"},
    "lena": {"jacket": ("#4f8a3a", "#346624", "#1f4416"), "hat": ("#e8d9b8", "#c2ae86"), "hair": "#8a4a22", "trim": "#e8e2d0", "braid": True},
    "jun": {"jacket": ("#3a54c8", "#25389a", "#152466"), "hat": ("#c03a2a", "#8a2418"), "hair": "#151515", "trim": "#e0e4f0"},
}


def frame(hip, lean=0, arms=((2, 5), (-1, 5)), legs=((2, 0), (-2, 0)), knees=None, head_tilt=0):
    return dict(hip=hip, lean=lean, arms=arms, legs=legs, knees=knees, head_tilt=head_tilt)


# Order matters. Same poses as the first placeholder sheet, refined.
FRAMES = [
    frame((8, 16)),  # 0 idle
    frame((8, 16), arms=((2, 6), (-1, 6))),  # 1 idle breath
    frame((8, 16), lean=1, arms=((3, 4), (-2, 5)), legs=((3, 0), (-3, 0))),  # 2-5 walk
    frame((8, 15), lean=1, arms=((1, 6), (0, 6)), legs=((1, 0), (-1, -1))),
    frame((8, 16), lean=1, arms=((-2, 5), (3, 4)), legs=((-3, 0), (3, 0))),
    frame((8, 15), lean=1, arms=((0, 6), (1, 6)), legs=((-1, -1), (1, 0))),
    frame((7, 16), lean=1, arms=((4, -5), (3, -1)), legs=((3, -3), (1, 0))),  # 6-9 climb
    frame((7, 15), lean=1, arms=((4, -3), (3, -5)), legs=((2, -1), (2, -3))),
    frame((7, 16), lean=1, arms=((3, -1), (4, -5)), legs=((1, 0), (3, -3))),
    frame((7, 15), lean=1, arms=((3, -5), (4, -3)), legs=((2, -3), (2, -1))),
    frame((7, 16), lean=1, arms=((4, -5), (3, -5)), legs=((2, -1), (1, 0))),  # 10-11 hang
    frame((7, 16), lean=0, arms=((4, -5), (3, -4)), legs=((1, 0), (2, -1))),
    frame((8, 14), lean=-1, arms=((3, -4), (-3, -3)), legs=((3, -2), (-2, -1))),  # 12-13 fall
    frame((8, 14), lean=-1, arms=((-3, -4), (3, -3)), legs=((-2, -2), (3, -1))),
    frame((8, 18), lean=2, arms=((4, 2), (-2, 3)), legs=((4, 0), (-3, 0)), head_tilt=1),  # 14-15 slip
    frame((8, 19), lean=3, arms=((4, 3), (0, 3)), legs=((4, 0), (-4, 0)), head_tilt=1),
    frame((8, 19), lean=1, arms=((3, 3), (1, 4)), legs=((3, 0), (-3, 0)), knees=((3, -2), None)),  # 16-17 rest
    frame((8, 19), lean=1, arms=((3, 4), (1, 4)), legs=((3, 0), (-3, 0)), knees=((3, -2), None)),
    frame((7, 18), lean=2, arms=((5, 4), (4, 2)), legs=((3, 0), (-3, 0))),  # 18 brace
    frame((7, 19), lean=2, arms=((6, 4), (5, 3)), legs=((3, 0), (-3, 0)), knees=((3, -2), None)),  # 19-20 help
    frame((7, 19), lean=1, arms=((5, 1), (4, 0)), legs=((3, 0), (-3, 0)), knees=((3, -2), None)),
    frame((8, 16), arms=((2, -6), (-2, -6)), legs=((2, 0), (-2, 0))),  # 21-22 celebrate
    frame((8, 15), arms=((3, -7), (-3, -6)), legs=((2, -1), (-2, -1))),
    frame((8, 17), lean=2, arms=((3, 5), (0, 6)), legs=((2, 0), (-2, 0)), head_tilt=1),  # 23-26 tired walk
    frame((8, 17), lean=2, arms=((2, 6), (1, 6)), legs=((1, 0), (-1, 0)), head_tilt=1),
    frame((8, 17), lean=2, arms=((0, 6), (3, 5)), legs=((-2, 0), (2, 0)), head_tilt=1),
    frame((8, 17), lean=2, arms=((1, 6), (2, 6)), legs=((-1, 0), (1, 0)), head_tilt=1),
]


def sx(x: float) -> int:
    return round(12 + (x - 8) * S)


def sy(y: float) -> int:
    return round(GROUND - (23 - y) * S)


def limb(d: ImageDraw.ImageDraw, ox, oy, points, colors, width):
    pts = [(ox + x, oy + y) for x, y in points]
    d.line(pts, fill=colors[1] + (255,), width=width, joint="curve")
    # A one-pixel highlight on the lit (upper-left) side.
    lit = [(x - 1, y - 1) for x, y in pts] if width > 2 else pts
    d.line(lit, fill=colors[0] + (255,), width=1)


def draw(d: ImageDraw.ImageDraw, ox: int, oy: int, f: dict, who: dict):
    jacket = [hex_rgb(c) for c in who["jacket"]]
    hat = [hex_rgb(c) for c in who["hat"]]
    hair = hex_rgb(who["hair"])
    trim = hex_rgb(who["trim"])
    hx, hy = sx(f["hip"][0]), sy(f["hip"][1])
    lean = round(f["lean"] * S)
    shx, shy = hx + lean, hy - 9  # shoulder

    def foot(i):
        fx, fy = f["legs"][i]
        return hx + round(fx * S), GROUND + round(fy * S)

    def knee(i):
        k = f["knees"][i] if f["knees"] and f["knees"][i] else None
        if k:
            return hx + round(k[0] * S), hy + 6 + round(k[1] * S)
        fx, fy = foot(i)
        return (hx + fx) // 2 + 1, (hy + fy) // 2

    def hand(i):
        ax, ay = f["arms"][i]
        return shx + 1 + round(ax * S), shy + 2 + round(ay * S)

    def elbow(i):
        hx2, hy2 = hand(i)
        return (shx + 1 + hx2) // 2 - (1 if hy2 < shy else 0), (shy + 2 + hy2) // 2 + (1 if hy2 > shy else 0)

    # Back leg, back arm (shaded).
    bf = foot(1)
    limb(d, ox, oy, [(hx - 1, hy), knee(1), bf], [PANTS[1], PANTS[2]], 3)
    d.rectangle([ox + bf[0] - 1, oy + bf[1] - 2, ox + bf[0] + 2, oy + bf[1]], fill=BOOT[2] + (255,))
    limb(d, ox, oy, [(shx, shy + 2), elbow(1), hand(1)], [jacket[2], jacket[2]], 3)
    bh = hand(1)
    d.rectangle([ox + bh[0], oy + bh[1], ox + bh[0] + 1, oy + bh[1] + 1], fill=GLOVE[1] + (255,))

    # Pack.
    d.rounded_rectangle([ox + shx - 6, oy + shy - 1, ox + shx - 2, oy + shy + 8], radius=1, fill=PACK[1] + (255,))
    d.line([(ox + shx - 6, oy + shy), (ox + shx - 6, oy + shy + 7)], fill=PACK[0] + (255,))
    d.line([(ox + shx - 5, oy + shy - 2), (ox + shx - 3, oy + shy - 2)], fill=PACK[2] + (255,))

    # Torso: jacket with a lit front panel, shaded back, hem and zip.
    torso = [(shx - 2, shy), (shx + 3, shy), (hx + 3, hy + 1), (hx - 2, hy + 1)]
    d.polygon([(ox + x, oy + y) for x, y in torso], fill=jacket[1] + (255,))
    d.line([(ox + shx - 1, oy + shy + 1), (ox + hx - 1, oy + hy)], fill=jacket[0] + (255,), width=1)
    d.line([(ox + shx + 2, oy + shy + 1), (ox + hx + 2, oy + hy)], fill=jacket[2] + (255,), width=1)
    d.line([(ox + hx - 2, oy + hy + 1), (ox + hx + 3, oy + hy + 1)], fill=jacket[2] + (255,))
    d.line([(ox + shx + 1, oy + shy + 1), (ox + hx + 1, oy + hy - 1)], fill=trim + (255,))
    # Shoulder strap.
    d.line([(ox + shx - 1, oy + shy), (ox + shx + 1, oy + shy + 5)], fill=PACK[2] + (255,))

    # Front leg and boot.
    ff = foot(0)
    limb(d, ox, oy, [(hx + 1, hy), knee(0), ff], PANTS, 3)
    d.rectangle([ox + ff[0] - 1, oy + ff[1] - 2, ox + ff[0] + 2, oy + ff[1]], fill=BOOT[1] + (255,))
    d.line([(ox + ff[0] - 1, oy + ff[1] - 2), (ox + ff[0] + 1, oy + ff[1] - 2)], fill=BOOT[0] + (255,))

    # Head: face, hair at the back, beanie with a band and a bobble.
    tilt = round(f["head_tilt"] * S)
    cx, cy = shx + 1 + tilt, shy - 4
    d.rectangle([ox + cx - 2, oy + cy - 2, ox + cx + 2, oy + cy + 2], fill=SKIN[0] + (255,))
    d.line([(ox + cx - 2, oy + cy + 2), (ox + cx + 1, oy + cy + 2)], fill=SKIN[1] + (255,))
    d.rectangle([ox + cx - 3, oy + cy - 1, ox + cx - 2, oy + cy + 2], fill=hair + (255,))
    if who.get("braid"):
        d.line([(ox + cx - 3, oy + cy + 2), (ox + cx - 4, oy + cy + 6)], fill=hair + (255,), width=2)
    d.point((ox + cx + 1, oy + cy), fill=(30, 22, 20, 255))  # eye
    d.point((ox + cx + 3, oy + cy + 1), fill=SKIN[1] + (255,))  # nose
    d.rectangle([ox + cx - 3, oy + cy - 5, ox + cx + 2, oy + cy - 2], fill=hat[0] + (255,))
    d.line([(ox + cx - 3, oy + cy - 2), (ox + cx + 2, oy + cy - 2)], fill=hat[1] + (255,))
    d.point((ox + cx - 2, oy + cy - 6), fill=hat[1] + (255,))
    d.point((ox + cx - 1, oy + cy - 6), fill=hat[0] + (255,))

    # Front arm last, with a glove.
    limb(d, ox, oy, [(shx + 1, shy + 2), elbow(0), hand(0)], jacket, 3)
    fh = hand(0)
    d.rectangle([ox + fh[0], oy + fh[1], ox + fh[0] + 1, oy + fh[1] + 1], fill=GLOVE[0] + (255,))


def main():
    rows = (len(FRAMES) + COLS - 1) // COLS
    out = OUT / "characters"
    out.mkdir(parents=True, exist_ok=True)
    for name, who in PARTY.items():
        sheet = Image.new("RGBA", (W * COLS, H * rows), (0, 0, 0, 0))
        d = ImageDraw.Draw(sheet)
        for index, f in enumerate(FRAMES):
            draw(d, (index % COLS) * W, (index // COLS) * H, f, who)
        selective_outline(sheet, cell=(W, H)).save(out / f"{name}.png")
        print(f"wrote {out / f'{name}.png'} ({len(FRAMES)} frames)")


if __name__ == "__main__":
    main()
