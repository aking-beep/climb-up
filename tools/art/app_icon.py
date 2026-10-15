"""
The CLIMB UP app icon, drawn in code: Kibo's snow-capped summit against a
sunrise, the sun rising behind the crater rim and a small climber's flag on
the top. Writes every size the game and the stores need:

  godot/assets/ui/icon.png                  256, the project / web icon
  godot/assets/android/icon_192.png         legacy launcher icon
  godot/assets/android/icon_foreground.png  adaptive icon, 432 (content in the safe zone)
  godot/assets/android/icon_background.png  adaptive icon, 432
  godot/assets/android/icon_monochrome.png  themed icon (Android 13+), 432
  store/icon-512.png                        Google Play listing icon

    python3 tools/art/app_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
S = 1024  # drawn large, scaled down


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def sky(size):
    im = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(im)
    stops = [(0.0, (42, 35, 80)), (0.38, (122, 63, 120)), (0.62, (224, 112, 138)), (0.8, (255, 168, 106)), (1.0, (255, 217, 138))]
    for y in range(size):
        t = y / (size - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                u = (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
                c = lerp(stops[i][1], stops[i + 1][1], u)
                break
        d.line([(0, y), (size, y)], fill=c + (255,))
    return im


def mountain(size, solid=None):
    """Kibo: a broad flat-topped volcano, snow on the crater rim, a flag."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = size / S
    base = 900 * k
    body = [(60 * k, base), (330 * k, 470 * k), (420 * k, 410 * k), (600 * k, 400 * k), (690 * k, 450 * k), (964 * k, base)]
    rock = solid or (58, 48, 92, 255)
    shade = solid or (40, 32, 70, 255)
    d.polygon(body + [(964 * k, size), (60 * k, size)], fill=rock)
    d.polygon([(600 * k, 400 * k), (690 * k, 450 * k), (964 * k, base), (964 * k, size), (640 * k, size), (560 * k, 640 * k)], fill=shade)
    snow = solid or (246, 240, 236, 255)
    d.polygon([(330 * k, 470 * k), (420 * k, 410 * k), (600 * k, 400 * k), (690 * k, 450 * k), (640 * k, 500 * k), (600 * k, 470 * k),
               (560 * k, 520 * k), (500 * k, 480 * k), (450 * k, 530 * k), (400 * k, 490 * k), (360 * k, 520 * k)], fill=snow)
    # The flag on the summit.
    d.line([(512 * k, 404 * k), (512 * k, 300 * k)], fill=solid or (250, 246, 240, 255), width=max(2, int(12 * k)))
    d.polygon([(518 * k, 302 * k), (600 * k, 324 * k), (518 * k, 348 * k)], fill=solid or (232, 120, 44, 255))
    return im


def sun(size):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = size / S
    cx, cy, r = 512 * k, 470 * k, 230 * k
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 238, 190, 255))
    glow = im.filter(ImageFilter.GaussianBlur(60 * k))
    return Image.alpha_composite(glow, im)


def full(size):
    im = sky(size)
    im = Image.alpha_composite(im, sun(size))
    return Image.alpha_composite(im, mountain(size))


def rounded(im, radius_frac=0.22):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0] - 1, im.size[1] - 1], radius=int(im.size[0] * radius_frac), fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def main():
    art = full(S)
    (ROOT / "store").mkdir(exist_ok=True)
    art.convert("RGB").resize((512, 512), Image.LANCZOS).save(ROOT / "store" / "icon-512.png")
    rounded(art).resize((256, 256), Image.LANCZOS).save(ROOT / "godot" / "assets" / "ui" / "icon.png")
    and_dir = ROOT / "godot" / "assets" / "android"
    and_dir.mkdir(parents=True, exist_ok=True)
    rounded(art).resize((192, 192), Image.LANCZOS).save(and_dir / "icon_192.png")
    # Adaptive: the launcher masks to a circle, squircle or square and may
    # move the layers; keep the summit inside the central 66%.
    # The summit, sun and flag sit inside the central safe zone; the
    # mountain's flanks run to the edges and may be cropped by the mask.
    Image.alpha_composite(sun(S), mountain(S)).resize((432, 432), Image.LANCZOS).save(and_dir / "icon_foreground.png")
    sky(S).resize((432, 432), Image.LANCZOS).save(and_dir / "icon_background.png")
    mountain(S, solid=(255, 255, 255, 255)).resize((432, 432), Image.LANCZOS).save(and_dir / "icon_monochrome.png")
    print("wrote icons")


if __name__ == "__main__":
    main()
