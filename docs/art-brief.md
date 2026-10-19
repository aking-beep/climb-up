# Art and audio brief: what a professional needs to replace

All art and sound in the Godot build is made by scripts in `tools/art`
and `tools/audio` (original, project-owned). It is clean and consistent
but it is placeholder quality. This lists each piece, where it lives, the
format the game expects, and what a finished version should do. Nothing
here should copy existing games' characters or art; the references in
`docs/hd2d-art-direction.md` are for mood only.

## Direction

A premium 2D mountain adventure: warm, readable characters with bold
outlines and big hands and feet, painted rock with clear holds, layered
skies and cloud seas with depth, and a light touch of drama in the light
(sunrise on the summit, headlamps at night). Holds and hazards must read
at a glance on a 6-inch phone held sideways: shape and colour first,
detail second.

Everything is drawn at 4× the world size and shown at a quarter scale
with smooth filtering, so a phone draws it at full resolution (`Art.tex`,
`Sheet.best`). One world pixel = 4 source pixels.

## Characters (highest priority)

`assets/characters/{you,marco,lena,jun}-hd.png` (from
`tools/art/characters_hd.py`): sprite sheets of 128 × 160 px frames (32 ×
40 world px), layout in `core/player/sheet.gd`. Harness, helmet or hat,
pack, chalk bag, quickdraws on the harness.

Needed animations (frames at 10–12 fps unless noted):

| Clip | Now | Wanted |
| --- | --- | --- |
| idle, walk, tired walk | yes | breathing idle; tired walk with hands on knees at stops |
| climb, hang | yes | separate hand-over-hand reach left/right, and a hang with weight on the feet |
| traverse | uses climb | side-stepping reach |
| crimp, sloper, pocket | none | three grips, so the hold in the hands is visible |
| dyno launch / air / catch | uses fall | crouch-and-spring (3 frames), reach (2), catch with a swing (4) |
| clip | none | one arm up, rope pulled to the draw (4 frames) |
| shake-out | none | one arm hanging, shaken (loop) |
| rest on rope | uses hang | sitting back in the harness, feet on the wall |
| lead fall / rope catch | slip | falling with the rope coming tight, a bounce |
| mantle, scramble | one pose each | full mantle over a lip (6 frames), four-limb scramble loop |
| brace, rest, help, celebrate | yes | help-up for two people (the short-rope on the descent too) |

## Holds, gear and the crag wall

`tools/art/crag_hd.py` → `assets/crag/`: crimp (16 × 16 world px), jug (18 ×
11), sloper (16 × 16), pocket (16 × 16), quickdraw (2 frames of 12 × 22:
open and clipped), anchor (18 × 16). Wanted: 3–4 variants of each hold,
chalk wear on the popular ones, a bolt glint, and an animated quickdraw
swing when clipped. The rope is drawn in code (`crag_level.gd`
`_rope_texture`); a textured rope strip (4 × 16) would replace it.

## Terrain and props

`tools/art/terrain_hd.py` → `assets/terrain/hd/`: per palette (Barranco
basalt, Lava Tower red, summit blue-grey) a 1024² solid rock, back wall
and climbable face, a 16 × 3 atlas of 64 px tiles for edges (grass, moss
and snow caps by the open sides' mask), slopes, face holds, scree and
boulders, plus ice and slabs. Tile rules are in
`core/world/terrain_tiles.gd`. Wanted: hand-painted tiles in the same
layout so they drop in, with more variation tiles.

`tools/art/props_hd.py` → `assets/terrain/props/hd/`: cairn, sign, grass,
pebbles, groundsel, lobelia, rest stone, exit post, tents, boulder, fire
(4 frames), stones, water, gear, artifacts, thistle, siafu ants,
raven. Same sizes as the pixel versions beside them.

## Backdrops, weather, light

`assets/scenery/*.png` (parallax far, mid and foreground layers per
level) and `assets/world/*.webp` (the camp's zone plates). Wanted: each
zone at three times of day (dawn, day, night) so the camp and the
descent can move through them; cloud layers that scroll; falling snow and
blown spindrift sprites; a sunrise light pass for Stella Point.

## UI

Menus and panels are drawn in code (`core/ui`): a paper card with ink
text and a spruce accent; touch buttons drawn at 4× in
`touch_controls.gd`; stars in `core/ui/star_row.gd`. Wanted: a small icon
set (bolt, crimp, sloper, pocket, jug, star, streak, settings, share),
a logo, and an app icon set for Android and iOS.

## Audio

`tools/audio/placeholders.py` → `assets/audio/placeholder/*.wav`, all
synthesized. Wanted, recorded or designed:

- Holds: a set of 3–4 takes each for rock, crimp, sloper, pocket and jug
  grabs; chalk; the clip (gate snap); the catch (slap); a rope whip and a
  catch; a ground thud.
- Ambience loops: wind (calm, gusting), camp (fire, tents, voices low),
  summit dawn.
- Cues: top-out, cairn, achievement, daily streak.
- Music: two quiet loops exist as hooks (`Audio.play_music("crag")` and
  `"camp"`); a composed score of 3–4 restrained pieces (crag, camp,
  summit night, the descent) would replace them. Music never plays on the
  expedition climbs: wind and breath only, by design.
