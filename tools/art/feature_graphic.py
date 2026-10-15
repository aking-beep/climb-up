"""The Play Store feature graphic (1024 x 500): the summit sunrise from the
game itself, without its HUD, with the title. The source frame:

    godot --rendering-driver opengl3 --path godot res://tests/shot.tscn -- out=/tmp/sun \
      scene=res://modes/expedition/levels/kilimanjaro/summit_night/summit_night.tscn \
      park=summit-night finish clean at=124,23 hold=4
    python3 tools/art/feature_graphic.py /tmp/sun_0.png
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
shot = Image.open(sys.argv[1]).convert("RGB")
# The sunrise and the peak, without the HUD: a 1024 x 500 window from the
# right of the frame, scaled.
w, h = shot.size
crop = shot.crop((int(w * 0.18), int(h * 0.12), w, int(h * 0.12) + int((w * 0.82) * 500 / 1024)))
img = crop.resize((1024, 500), Image.LANCZOS)
# Darken the left for the words.
shade = Image.new("L", (1024, 500))
d = ImageDraw.Draw(shade)
for x in range(1024):
    d.line([(x, 0), (x, 500)], fill=int(max(0, 170 - x * 0.33)))
img = Image.composite(Image.new("RGB", img.size, (20, 16, 40)), img, shade)
draw = ImageDraw.Draw(img)
title = ImageFont.truetype(str(ROOT / "godot/assets/fonts/Fraunces_600SemiBold.ttf"), 96)
sub = ImageFont.truetype(str(ROOT / "godot/assets/fonts/Outfit_500Medium.ttf"), 30)
glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
ImageDraw.Draw(glow).text((56, 150), "CLIMB UP", font=title, fill=(0, 0, 0, 200))
img.paste(glow.filter(ImageFilter.GaussianBlur(6)), (0, 0), glow.filter(ImageFilter.GaussianBlur(6)))
draw.text((56, 150), "CLIMB UP", font=title, fill=(255, 236, 196))
draw.text((60, 270), "Crag routes and a Kilimanjaro expedition.", font=sub, fill=(250, 240, 225))
draw.text((60, 310), "Bring the whole team home.", font=sub, fill=(250, 240, 225))
img.save(ROOT / "store/feature-graphic-1024x500.png")
print("store/feature-graphic-1024x500.png")
