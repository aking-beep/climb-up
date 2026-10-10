"""
Side-view party sprites for the climbing scenes: You, Marco, Lena and Jun.
32 x 40 px frames, 8 columns, 27 frames in the order the clip table in
src/features/climbing/sprites.ts expects.

HD-2D proportions: a large head (about a third of the figure) on a compact
body, so faces and gear read at phone size. Three-tone shading lit from the
upper left, a warm rim light on lit edges, and a soft selective outline.
Every beanie carries a headlamp for the summit night.

    python3 tools/art/characters.py
"""

import numpy as np
from PIL import Image, ImageDraw

from pixel import OUT, hex_rgb, selective_outline

W, H, COLS = 32, 40, 8
GROUND = 39
CX = 16

SKIN = [hex_rgb("#f6d2a0"), hex_rgb("#e0aa76"), hex_rgb("#b87c4e")]
PANTS = [hex_rgb("#7a6754"), hex_rgb("#594a3c"), hex_rgb("#3d332a")]
BOOT = [hex_rgb("#a0683a"), hex_rgb("#6e4020"), hex_rgb("#3e2210")]
SOLE = hex_rgb("#2a2420")
PACK = [hex_rgb("#a8864f"), hex_rgb("#7d5f36"), hex_rgb("#4f3b22")]
MAT = [hex_rgb("#5aa0b8"), hex_rgb("#3a7086")]
GLOVE = [hex_rgb("#55504b"), hex_rgb("#383431")]
LAMP = [hex_rgb("#d8dde0"), hex_rgb("#8c949a"), hex_rgb("#ffe58a")]

PARTY = {
    "you": {"jacket": ("#9aa451", "#727c36", "#4c5422"), "hat": ("#f0efe6", "#cfccbe", "#a8a596"), "hair": ("#7a4520", "#56301a"), "trim": "#ece6d0"},
    "marco": {"jacket": ("#e8663a", "#b8441c", "#7c2a0c"), "hat": ("#3a4a5e", "#283444", "#1a222e"), "hair": ("#3a2416", "#22140c"), "trim": "#f6cd6a"},
    "lena": {"jacket": ("#5c9a44", "#3e742c", "#264c1a"), "hat": ("#efe2c2", "#cdb990", "#a69064"), "hair": ("#9a5428", "#6c3818"), "trim": "#f0ead8", "braid": True},
    "jun": {"jacket": ("#4864d8", "#2e46a8", "#1a2a70"), "hat": ("#d4483a", "#9a2c20", "#6a1c14"), "hair": ("#1e1e22", "#101012"), "trim": "#e6eaf4"},
}


def frame(hip, lean=0, arms=((2, 5), (-1, 5)), legs=((2, 0), (-2, 0)), knees=None, head_tilt=0):
    return dict(hip=hip, lean=lean, arms=arms, legs=legs, knees=knees, head_tilt=head_tilt)


# Order matters; the pose table is authored in the original 16 x 24 units.
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

LEG = 1.45  # leg offsets, old units to px
ARM = 1.2
LEAN = 1.5
DROP = 1.6  # crouch depth: how far the hip sinks per old unit


def rgba(c):
    return tuple(c) + (255,)


def limb(d, ox, oy, pts, light, mid, dark, width=3):
    p = [(ox + x, oy + y) for x, y in pts]
    d.line(p, fill=rgba(dark), width=width, joint="curve")
    d.line([(x - 0.5, y - 0.5) for x, y in p], fill=rgba(mid), width=max(1, width - 1), joint="curve")
    d.line([(x - 1, y - 1) for x, y in p], fill=rgba(light), width=1)


def draw(d: ImageDraw.ImageDraw, ox: int, oy: int, f: dict, who: dict):
    jl, jm, jd = [hex_rgb(c) for c in who["jacket"]]
    hl, hm, hd = [hex_rgb(c) for c in who["hat"]]
    hair, hair_d = [hex_rgb(c) for c in who["hair"]]
    trim = hex_rgb(who["trim"])

    hx = CX + round((f["hip"][0] - 8) * 1.4)
    hy = GROUND - 10 - round((16 - f["hip"][1]) * -DROP) if f["hip"][1] >= 16 else GROUND - 10 - round((16 - f["hip"][1]) * 1.2)
    lean = round(f["lean"] * LEAN)
    sx, sy = hx + lean, hy - 8  # shoulder

    def foot(i):
        fx, fy = f["legs"][i]
        return hx + round(fx * LEG), GROUND + round(fy * LEG)

    def knee(i):
        k = f["knees"][i] if f["knees"] and f["knees"][i] else None
        if k:
            return hx + round(k[0] * LEG), hy + 5 + round(k[1] * LEG)
        fx, fy = foot(i)
        return (hx + fx) // 2 + 1, (hy + fy) // 2

    def hand(i):
        ax, ay = f["arms"][i]
        # Reaching up clears the big head; hanging arms stay short.
        return sx + 1 + round(ax * ARM), sy + 2 + round(ay * (2.0 if ay < 0 else ARM))

    def elbow(i):
        hx2, hy2 = hand(i)
        bend = 1 if hy2 > sy else -1
        return (sx + 1 + hx2) // 2 - (1 if bend < 0 else 0), (sy + 2 + hy2) // 2 + bend

    def boot(px, py, tone):
        d.rectangle([ox + px - 2, oy + py - 3, ox + px + 2, oy + py - 1], fill=rgba(BOOT[tone]))
        d.line([(ox + px - 2, oy + py), (ox + px + 3, oy + py)], fill=rgba(SOLE))
        d.line([(ox + px - 1, oy + py - 3), (ox + px + 1, oy + py - 3)], fill=rgba(BOOT[0] if tone == 1 else BOOT[1]))

    # Back leg and back arm, in shade.
    bf = foot(1)
    limb(d, ox, oy, [(hx - 1, hy), knee(1), (bf[0], bf[1] - 3)], PANTS[1], PANTS[2], PANTS[2], 4)
    boot(bf[0], bf[1], 2)
    limb(d, ox, oy, [(sx - 1, sy + 2), elbow(1), hand(1)], jd, jd, jd, 3)
    bh = hand(1)
    d.rectangle([ox + bh[0], oy + bh[1], ox + bh[0] + 1, oy + bh[1] + 1], fill=rgba(GLOVE[1]))

    # Pack with a lid, side strap, and a rolled mat on top.
    px0, py0 = sx - 7, sy
    d.rounded_rectangle([ox + px0, oy + py0, ox + px0 + 4, oy + py0 + 8], radius=2, fill=rgba(PACK[1]))
    d.line([(ox + px0, oy + py0 + 2), (ox + px0, oy + py0 + 6)], fill=rgba(PACK[0]))
    d.line([(ox + px0 + 1, oy + py0 + 3), (ox + px0 + 3, oy + py0 + 3)], fill=rgba(PACK[2]))
    d.rounded_rectangle([ox + px0, oy + py0 - 2, ox + px0 + 4, oy + py0], radius=1, fill=rgba(MAT[0]))
    d.point((ox + px0 + 4, oy + py0 - 1), fill=rgba(MAT[1]))

    # Torso: lit front, shaded back, hem, zip, collar, chest strap.
    torso = [(sx - 3, sy), (sx + 4, sy), (hx + 4, hy + 2), (hx - 3, hy + 2)]
    d.polygon([(ox + x, oy + y) for x, y in torso], fill=rgba(jm))
    d.line([(ox + sx - 2, oy + sy + 1), (ox + hx - 2, oy + hy + 1)], fill=rgba(jl), width=2)
    d.line([(ox + sx + 4, oy + sy + 1), (ox + hx + 4, oy + hy + 1)], fill=rgba(jd), width=1)
    d.line([(ox + hx - 3, oy + hy + 2), (ox + hx + 4, oy + hy + 2)], fill=rgba(jd))
    d.line([(ox + sx + 2, oy + sy + 2), (ox + hx + 2, oy + hy)], fill=rgba(trim))
    d.line([(ox + sx - 2, oy + sy), (ox + sx + 3, oy + sy)], fill=rgba(trim))
    d.line([(ox + sx - 3, oy + sy + 4), (ox + sx + 3, oy + sy + 4)], fill=rgba(PACK[2]))

    # Front leg and boot.
    ff = foot(0)
    limb(d, ox, oy, [(hx + 1, hy), knee(0), (ff[0], ff[1] - 3)], PANTS[0], PANTS[1], PANTS[2], 4)
    boot(ff[0], ff[1], 1)

    # Head: big and readable.
    tilt = round(f["head_tilt"] * 1.5)
    cx, cy = sx + 1 + tilt, sy - 6  # face centre
    d.rounded_rectangle([ox + cx - 4, oy + cy - 3, ox + cx + 4, oy + cy + 4], radius=2, fill=rgba(SKIN[0]))
    d.line([(ox + cx + 4, oy + cy - 1), (ox + cx + 4, oy + cy + 3)], fill=rgba(SKIN[1]))
    d.line([(ox + cx - 2, oy + cy + 4), (ox + cx + 3, oy + cy + 4)], fill=rgba(SKIN[1]))
    # Hair behind and over the ear.
    d.rectangle([ox + cx - 5, oy + cy - 2, ox + cx - 2, oy + cy + 3], fill=rgba(hair))
    d.line([(ox + cx - 5, oy + cy + 3), (ox + cx - 3, oy + cy + 3)], fill=rgba(hair_d))
    if who.get("braid"):
        d.line([(ox + cx - 5, oy + cy + 3), (ox + cx - 6, oy + cy + 9)], fill=rgba(hair), width=2)
        d.point((ox + cx - 6, oy + cy + 9), fill=rgba(trim))
    d.point((ox + cx - 2, oy + cy + 1), fill=rgba(SKIN[2]))  # ear
    # Eye with a catch-light, brow, nose, cheek.
    d.rectangle([ox + cx + 1, oy + cy, ox + cx + 2, oy + cy + 1], fill=(34, 26, 24, 255))
    d.point((ox + cx + 1, oy + cy), fill=(250, 246, 240, 255))
    d.line([(ox + cx + 1, oy + cy - 2), (ox + cx + 3, oy + cy - 2)], fill=rgba(hair_d))
    d.point((ox + cx + 5, oy + cy + 2), fill=rgba(SKIN[1]))
    d.point((ox + cx + 2, oy + cy + 3), fill=(222, 140, 120, 255))
    # Beanie: crown, folded band, bobble, and a headlamp on the band.
    d.rounded_rectangle([ox + cx - 5, oy + cy - 8, ox + cx + 4, oy + cy - 2], radius=3, fill=rgba(hm))
    d.line([(ox + cx - 4, oy + cy - 7), (ox + cx + 1, oy + cy - 7)], fill=rgba(hl))
    d.rectangle([ox + cx - 5, oy + cy - 3, ox + cx + 4, oy + cy - 2], fill=rgba(hd))
    d.rectangle([ox + cx - 2, oy + cy - 10, ox + cx, oy + cy - 8], fill=rgba(hl))
    d.rectangle([ox + cx + 3, oy + cy - 4, ox + cx + 5, oy + cy - 2], fill=rgba(LAMP[1]))
    d.point((ox + cx + 5, oy + cy - 3), fill=rgba(LAMP[2]))

    # Front arm last, with a glove.
    limb(d, ox, oy, [(sx + 1, sy + 2), elbow(0), hand(0)], jl, jm, jd, 3)
    fh = hand(0)
    d.rectangle([ox + fh[0], oy + fh[1], ox + fh[0] + 2, oy + fh[1] + 1], fill=rgba(GLOVE[0]))
    d.point((ox + fh[0], oy + fh[1]), fill=rgba(GLOVE[1]))


def rim_light(image: Image.Image, cell: tuple[int, int]) -> Image.Image:
    """Warm light on edges facing the upper left."""
    a = np.array(image).astype(int)
    out = a.copy()
    h, w, _ = a.shape
    for y in range(1, h):
        for x in range(1, w):
            if a[y, x, 3] == 0:
                continue
            if x % cell[0] == 0 or y % cell[1] == 0:
                continue
            if a[y, x - 1, 3] == 0 or a[y - 1, x, 3] == 0:
                out[y, x, :3] = np.minimum(255, a[y, x, :3] * 1.12 + np.array([18, 12, 0]))
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def main():
    rows = (len(FRAMES) + COLS - 1) // COLS
    out = OUT / "characters"
    out.mkdir(parents=True, exist_ok=True)
    for name, who in PARTY.items():
        sheet = Image.new("RGBA", (W * COLS, H * rows), (0, 0, 0, 0))
        d = ImageDraw.Draw(sheet)
        for index, f in enumerate(FRAMES):
            draw(d, (index % COLS) * W, (index // COLS) * H, f, who)
        sheet = rim_light(sheet, (W, H))
        selective_outline(sheet, cell=(W, H), darken=0.32).save(out / f"{name}.png")
        print(f"wrote {out / f'{name}.png'} ({len(FRAMES)} frames)")


if __name__ == "__main__":
    main()
