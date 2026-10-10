"""
Painted background layers for the Barranco Wall, generated so they can be
regenerated and tuned. Original artwork inspired by the place: Kibo's
southern ice cliffs above, a valley of giant groundsels, layered lava in the
wall, and dark foreground plants. Not a survey of the real landscape.

    python3 tools/art/scenery.py
"""

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from pixel import OUT, fbm, hex_rgb

RNG_SEED = 41


def mix(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return np.asarray(a, dtype=float) * (1 - t) + np.asarray(b, dtype=float) * t


def ridge_line(width: int, rng, base: float, rough: float, cells: int) -> np.ndarray:
    line = fbm(width, 1, cells, 4, rng, wrap=False)[0]
    return base + (line - 0.5) * rough


def kibo(width=1400, height=560) -> Image.Image:
    """Kibo's broad summit dome with a band of southern ice cliffs, hazy and far."""
    rng = np.random.default_rng(RNG_SEED)
    xs = np.arange(width)
    t = (xs - width * 0.55) / (width * 0.62)
    dome = np.clip(1 - t**2, 0, 1) ** 0.9
    rim = height * 0.22
    top = height * 0.98 - dome * (height * 0.98 - rim) + ridge_line(width, rng, 0, height * 0.035, 22)
    top = np.minimum(top, height * 0.98 - dome * (height * 0.98 - rim) * 0.97 + 6)
    yy, xx = np.mgrid[0:height, 0:width]
    inside = yy >= top[None, :]
    depth = (yy - top[None, :]) / height

    gullies = fbm(width, height, 30, 3, rng, wrap=False)
    streaks = fbm(width, 6, 140, 2, rng, wrap=False)
    streaks = np.repeat(streaks, height // 6 + 1, axis=0)[:height]
    rock = mix(hex_rgb("#6a625a"), hex_rgb("#3d3733"), np.clip(gullies * 0.7 + streaks * 0.6 - 0.25, 0, 1))
    rock = mix(rock, hex_rgb("#9a8672"), np.clip((-t[None, :] * 0.6 + 0.15) * (1 - depth * 2.5), 0, 0.5))

    # The ice: a continuous cap whose lower edge breaks into short cliffs.
    band = (0.09 + fbm(width, 1, 10, 3, rng, wrap=False)[0] * 0.07) * (dome > 0.35)
    teeth = fbm(width, 1, 90, 2, rng, wrap=False)[0]
    lower = band + (teeth - 0.5) * 0.05
    gaps = fbm(width, 1, 7, 2, rng, wrap=False)[0] < 0.3
    lower = np.where(gaps, lower * 0.35, lower)
    ice = inside & (depth < lower[None, :])
    cliff = ice & (depth > lower[None, :] - 0.022)
    ice_rgb = mix(hex_rgb("#f7f8f5"), hex_rgb("#cfdae0"), np.clip(depth / 0.16, 0, 1))
    rgb = np.where(ice[..., None], ice_rgb, rock)
    rgb = np.where(cliff[..., None], mix(np.asarray(hex_rgb("#a9bccb"), dtype=float), rock, 0.15), rgb)
    shadow = inside & ~ice & (depth < lower[None, :] + 0.015)
    rgb = np.where(shadow[..., None], mix(rgb, hex_rgb("#2c2a2c"), 0.35), rgb)

    haze = hex_rgb("#b9c5c9")
    rgb = mix(rgb, haze, np.clip(0.36 + depth * 1.1, 0, 0.92))
    alpha = np.where(inside, 255, 0) * np.clip(1.4 - depth * 1.6, 0, 1)
    img = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")
    return img.filter(ImageFilter.GaussianBlur(0.7))


def rosette(d: ImageDraw.ImageDraw, cx, cy, r, leaf, tip, core, rng):
    for k in range(26):
        a = -np.pi + (k / 26) * 2 * np.pi + rng.uniform(-0.08, 0.08)
        length = r * rng.uniform(0.75, 1.1)
        if np.sin(a) > 0.2:
            length *= 0.75  # leaves droop below the crown
        ex, ey = cx + np.cos(a) * length, cy + np.sin(a) * length * 0.8
        d.line([(cx, cy), (ex, ey)], fill=leaf, width=max(2, int(r * 0.16)))
        d.line([(cx + (ex - cx) * 0.6, cy + (ey - cy) * 0.6), (ex, ey)], fill=tip, width=max(1, int(r * 0.1)))
    d.ellipse([cx - r * 0.28, cy - r * 0.22, cx + r * 0.28, cy + r * 0.22], fill=core)


def groundsel(d: ImageDraw.ImageDraw, x, base, height, scale, colors, rng):
    """A giant groundsel: a shaggy trunk that forks into leaf rosettes."""
    trunk, shag, leaf, tip, core = colors
    lean = rng.uniform(-0.12, 0.12)
    w = max(3, 9 * scale)
    top = (x + lean * height, base - height)
    d.line([(x, base), top], fill=trunk, width=int(w))
    for k in range(int(height / 6)):
        yy = base - k * 6 - rng.uniform(0, 4)
        xx = x + lean * (base - yy)
        d.line([(xx - w * 0.6, yy), (xx + w * 0.6, yy + 3)], fill=shag, width=max(1, int(w * 0.35)))
    arms = rng.integers(1, 4)
    for a in range(arms):
        dx = (a - (arms - 1) / 2) * 26 * scale + rng.uniform(-6, 6) * scale
        ah = rng.uniform(16, 34) * scale
        end = (top[0] + dx, top[1] - ah)
        d.line([top, end], fill=trunk, width=max(2, int(w * 0.75)))
        rosette(d, end[0], end[1], 17 * scale, leaf, tip, core, rng)


def valley(width=1400, height=520) -> Image.Image:
    """The Barranco valley floor with groundsels, three depths deep."""
    rng = np.random.default_rng(RNG_SEED + 1)
    s = 2  # draw at 2x, then reduce for soft painted edges
    W, H = width * s, height * s
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ground_top = ridge_line(W, rng, H * 0.24, H * 0.08, 6)
    yy, xx = np.mgrid[0:H, 0:W]
    inside = yy >= ground_top[None, :]
    scrub = fbm(W, H, 90, 3, rng, wrap=False)
    band = fbm(W, H, 6, 2, rng, wrap=False)
    depth = np.clip((yy - ground_top[None, :]) / (H * 0.76), 0, 1)
    rgb = mix(hex_rgb("#8b8466"), hex_rgb("#5b5640"), np.clip(scrub * 0.9 + band * 0.4 - 0.25, 0, 1))
    rgb = mix(rgb, hex_rgb("#4a4232"), depth * 0.6)
    rgb = mix(rgb, hex_rgb("#c2c6bf"), np.clip(0.55 - depth * 1.2, 0, 0.55))  # haze at the far edge
    alpha = np.where(inside, 255, 0)
    img = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)

    # Boulders and groundsels, far to near.
    for layer, (count, scale, haze) in enumerate([(14, 0.7, 0.55), (9, 1.1, 0.3), (6, 1.7, 0.1)]):
        def tone(c):
            return tuple(int(v) for v in mix(hex_rgb(c), hex_rgb("#c2c6bf"), haze)) + (255,)
        colors = (tone("#3a3027"), tone("#5a4a3a"), tone("#6f8357"), tone("#a9b884"), tone("#3e4a30"))
        for _ in range(count):
            x = rng.uniform(0, W)
            base = ground_top[int(min(W - 1, max(0, x)))] + H * (0.08 + layer * 0.22) + rng.uniform(0, H * 0.08)
            if rng.random() < 0.35:
                r = rng.uniform(14, 34) * scale
                d.ellipse([x - r * 1.3, base - r, x + r * 1.3, base + r * 0.3], fill=tone("#5f554b"))
                d.ellipse([x - r * 1.1, base - r, x + r * 0.7, base - r * 0.4], fill=tone("#7d7164"))
            else:
                groundsel(d, x, base, rng.uniform(90, 170) * scale, scale * s / 1.4, colors, rng)
    return img.resize((width, height), Image.LANCZOS)


CLIFF_TONES = {
    "barranco": ("#2e2620", "#86735f", None),
    "lava": ("#331d16", "#9a5a3e", None),
    "frost": ("#1c2028", "#5c6270", "#dfe8f0"),
}


def cliff(size=256, tone="barranco") -> Image.Image:
    """Tileable layered lava with columnar fractures, for the wall behind the play space."""
    rng = np.random.default_rng(RNG_SEED + 2)
    dark, light, frost = CLIFF_TONES[tone]
    warp = fbm(size, size, 2, 3, rng)
    grain = fbm(size, size, 24, 3, rng)
    blotch = fbm(size, size, 6, 2, rng)
    yy, xx = np.mgrid[0:size, 0:size]
    phase = yy / size * 4 + warp * 1.2
    flow = phase % 1.0
    # Each flow is lighter at its top and darker toward its base.
    v = 0.62 - flow * 0.32 + (grain - 0.5) * 0.35 + (blotch - 0.5) * 0.25
    v = np.where(flow < 0.04, v + 0.12, v)
    # Columnar joints: near-vertical dark cracks, broken by the flows.
    cols = fbm(size, size, 9, 1, rng)
    cracks = (np.abs(((xx / size * 9 + warp * 0.6) % 1.0) - 0.5) < 0.025) & (cols > 0.45)
    v = np.where(cracks, v - 0.28, v)
    rgb = mix(hex_rgb(dark), hex_rgb(light), np.clip(v, 0, 1))
    if frost:
        # Rime on the tops of each flow and scattered in the grain.
        rime = (flow < 0.06) | ((grain > 0.66) & (blotch > 0.5))
        rgb = np.where(rime[..., None], mix(rgb, hex_rgb(frost), 0.7), rgb)
    return Image.fromarray(np.dstack([rgb, np.full((size, size), 255)]).astype(np.uint8), "RGBA")


def foreground(width=1400, height=420, plants=True, dark=(24, 19, 16, 255), rim=(58, 46, 36, 255)) -> Image.Image:
    """Near, out-of-focus plants and rock; drawn dark with a lit rim."""
    rng = np.random.default_rng(RNG_SEED + 3)
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    colors = (dark, dark, dark, rim, dark)
    def rock(x0, x1, peak):
        xs = np.linspace(x0, x1, 40)
        n = fbm(40, 1, 8, 3, rng, wrap=False)[0]
        hump = np.sin(np.linspace(0, np.pi, 40)) ** 0.7
        pts = [(x, height - hump[i] * height * peak * (0.75 + n[i] * 0.5)) for i, x in enumerate(xs)]
        d.polygon([(x0, height)] + pts + [(x1, height)], fill=dark)
        d.line(pts[2:18], fill=rim, width=3)

    rock(-20, width * 0.44, 0.55)
    rock(width * 0.6, width + 20, 0.48)
    if plants:
        groundsel(d, width * 0.1, height * 0.55, height * 0.36, 2.2, colors, rng)
        groundsel(d, width * 0.9, height * 0.6, height * 0.28, 1.8, colors, rng)
    for _ in range(40):
        x = rng.uniform(0, width)
        y = height - rng.uniform(0, height * 0.18)
        d.line([(x, y), (x + rng.uniform(-14, 14), y - rng.uniform(16, 50))], fill=rim if rng.random() < 0.3 else dark, width=3)
    return img


def plateau(width=1400, height=520) -> Image.Image:
    """The Shira plateau: open heath and heather, the tower's foot in haze."""
    rng = np.random.default_rng(RNG_SEED + 5)
    s = 2
    W, H = width * s, height * s
    ground_top = ridge_line(W, rng, H * 0.3, H * 0.05, 4)
    yy, xx = np.mgrid[0:H, 0:W]
    inside = yy >= ground_top[None, :]
    heath = fbm(W, H, 70, 3, rng, wrap=False)
    depth = np.clip((yy - ground_top[None, :]) / (H * 0.7), 0, 1)
    rgb = mix(hex_rgb("#9c8a62"), hex_rgb("#6b5e40"), np.clip(heath * 0.9 - 0.15, 0, 1))
    rgb = mix(rgb, hex_rgb("#4e4330"), depth * 0.55)
    rgb = mix(rgb, hex_rgb("#c8c4b8"), np.clip(0.5 - depth * 1.3, 0, 0.5))
    img = Image.fromarray(np.dstack([rgb, np.where(inside, 255, 0)]).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    for layer, (count, scale, haze) in enumerate([(40, 0.6, 0.5), (26, 1.0, 0.28), (14, 1.6, 0.08)]):
        def tone(c):
            return tuple(int(v) for v in mix(hex_rgb(c), hex_rgb("#c8c4b8"), haze)) + (255,)
        for _ in range(count):
            x = rng.uniform(0, W)
            base = ground_top[int(min(W - 1, max(0, x)))] + H * (0.06 + layer * 0.2) + rng.uniform(0, H * 0.08)
            r = rng.uniform(10, 26) * scale
            if rng.random() < 0.25:
                d.ellipse([x - r * 1.4, base - r, x + r * 1.4, base + r * 0.3], fill=tone("#5d4a3e"))
                d.ellipse([x - r, base - r, x + r * 0.6, base - r * 0.4], fill=tone("#86665a"))
            else:
                d.ellipse([x - r * 1.3, base - r * 0.9, x + r * 1.3, base + r * 0.2], fill=tone("#5f6a3e"))
                d.ellipse([x - r, base - r * 0.9, x + r * 0.5, base - r * 0.3], fill=tone("#8a9056"))
                for _ in range(4):
                    fx = x + rng.uniform(-r, r)
                    d.point((fx, base - r * rng.uniform(0.4, 0.9)), fill=tone("#c4a0c8"))
    return img.resize((width, height), Image.LANCZOS)


def cloud_sea(width=1400, height=560) -> Image.Image:
    """Night view from the summit slope: Mawenzi's jagged peak over a sea of cloud."""
    rng = np.random.default_rng(RNG_SEED + 6)
    yy, xx = np.mgrid[0:height, 0:width]
    peak_x = width * 0.72
    t = np.abs(xx[0] - peak_x) / (width * 0.22)
    spires = ridge_line(width, rng, 0, height * 0.18, 60)
    top = height * 0.62 - np.clip(1 - t, 0, 1) ** 1.3 * height * 0.42 + np.abs(spires)
    mountain = yy >= top[None, :]
    rock = mix(hex_rgb("#2c3346"), hex_rgb("#1a1e2c"), np.clip(fbm(width, height, 50, 3, rng, wrap=False) * 1.2 - 0.2, 0, 1))
    rock = mix(rock, hex_rgb("#6c7896"), np.clip((top[None, :] + 30 - yy) / 30, 0, 1) * 0.5)  # moonlit edges
    sea_top = height * 0.66 + ridge_line(width, rng, 0, height * 0.03, 12)
    puff = fbm(width, height, 18, 4, rng, wrap=False)
    sea = yy >= (sea_top[None, :] - puff * height * 0.08)
    cloud = mix(hex_rgb("#5a6684"), hex_rgb("#a8b4cc"), np.clip(puff * 1.3 - 0.2 - (yy - height * 0.66) / height, 0, 1))
    rgb = np.where(sea[..., None], cloud, rock)
    alpha = np.where(mountain | sea, 255, 0)
    img = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")
    return img.filter(ImageFilter.GaussianBlur(0.8))


def main():
    out = OUT / "scenery"
    out.mkdir(parents=True, exist_ok=True)
    for name, make in [
        ("kibo", kibo),
        ("valley", valley),
        ("cliff", cliff),
        ("foreground", foreground),
        ("lava-cliff", lambda: cliff(tone="lava")),
        ("plateau", plateau),
        ("lava-foreground", lambda: foreground(plants=False, dark=(30, 18, 14, 255), rim=(92, 52, 36, 255))),
        ("summit-cliff", lambda: cliff(tone="frost")),
        ("summit-sea", cloud_sea),
        ("summit-foreground", lambda: foreground(plants=False, dark=(16, 18, 26, 255), rim=(120, 136, 164, 255))),
    ]:
        path = out / (f"{name}.png" if name.startswith(("lava", "plateau", "summit")) else f"barranco-{name}.png")
        make().save(path, optimize=True)
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
