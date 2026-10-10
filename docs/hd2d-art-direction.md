# HD-2D art direction

CLIMB UP should look like a small, lit, physical world: pixel-art people
standing in painted, layered landscapes, seen through a lens. The references
are a *kind* of presentation (pixel sprites in dimensional, lit scenery). We
borrow no assets, characters, layouts, or UI from any existing game.

This document sets the target. Most of it is **not yet achieved**: the current
Barranco scene uses programmer placeholder sprites and procedural geometry for
the wall. See [asset-manifest.md](asset-manifest.md) for what exists.

## Principles

1. **Pixels for people, paint for places.** Characters and interactable props
   are crisp pixel art at an integer scale. Distant scenery is painterly and
   softer. The contrast is what reads as HD-2D.
2. **Depth from layers, not distortion.** Separate planes at different parallax
   rates, haze between them, focus falling off front and back. Never stretch or
   skew one flat image to fake depth.
3. **One light.** Each scene has one key light direction (Barranco morning:
   upper left, warm) and everything agrees with it: lit tops on ledges, shaded
   undersides, cast shadows falling the same way.
4. **The mountain is the antagonist, not the decoration.** Weather, light, and
   haze change with the expedition's weather risk and time of day.
5. **Readable first.** Climbable rock must always be distinguishable from solid
   rock and from background at a glance, in every weather.

## Palette

Barranco / alpine desert, morning (from the existing party sprites and
`src/theme.ts`):

| Role | Hex | Notes |
| --- | --- | --- |
| Solid rock | `#3e3732` | volcanic, warm grey |
| Rock lit edge | `#9a8a74` | key light catches tops |
| Rock shadow | `#211c19` | undersides |
| Climbable face | `#6a5d51` | lighter than solid rock, with darker holds `#3f362f` |
| Loose rock | `#7c6a57` | warmer and speckled `#a08b72`, reads as "unsafe" |
| Cliff backdrop | `#6e6359` → `#463d36` | vertical gradient, lava-flow strata |
| Sky (day) | `#8fa6ae` → `#f3efe6` | from `skyColors()` |
| Haze | `#f0eade` at 0.55 | at the horizon band |
| UI paper / ink | `#f3efe6` / `#1c1915` | existing theme |
| UI spruce | `#1f3d34` | primary actions |
| Stamina | `#7fa36b` / `#d9a441` / `#c0573e` | ok / low / critical, always paired with text |

Each mountain zone gets its own palette when it gets a playable scene
(rainforest, moorland, alpine desert, glacier and summit night).

## Characters

- Party identities from the existing front-facing sprites: **You** olive
  jacket, **Marco** rust-red, **Lena** forest green, **Jun** cobalt. White
  beanie and brown boots are shared.
- Side-view gameplay sprites: **16 × 24 px frames**, the figure about 20 px tall,
  feet on the bottom row, centred at x = 8. One-pixel dark outline (`#1b161a`).
- Rendered at an integer scale (currently `round(tile × 1.45 / 20)`), sampled
  nearest-neighbour. No filtering, no sub-pixel scaling of sprites.
- A drop shadow (soft dark ellipse) under any grounded character.

### Animation set

Frame order is fixed by `tools/sprites/placeholder_sheet.py` and the clip table
in `src/features/climbing/sprites.ts`. Replacement art must keep the order or
ship its own clip table.

| State | Frames | Timing |
| --- | --- | --- |
| idle | 0–1 | 700 / 500 ms |
| walk | 2–5 | 120 ms each |
| tired walk | 23–26 | 190 ms each |
| climb | 6–9 | 170 ms each |
| hang | 10–11 | 600 / 450 ms |
| fall | 12–13 | 90 ms |
| slip | 12, 13, 14, 15 (one-shot) | 90, 90, 160, 400 ms |
| rest | 16–17 | 800 / 700 ms |
| brace | 18 | held |
| help | 19–20 | 260 ms |
| celebrate | 21–22 | 300 ms |

Still missing for the full target: running, kneeling (separate from rest),
carrying, and a dedicated "helping a teammate up" two-person sequence.

## Environments

The ten-layer stack (back to front), as implemented in `ClimbCanvas.tsx`:

| # | Layer | Parallax | Focus |
| --- | --- | --- | --- |
| 1 | Sky gradient and sun glow | 0 | – |
| 2 | Distant range | ~0.04 | soft blur |
| 3 | Clouds and horizon haze | ~0.1, drifting | – |
| 4 | Valley floor, far ridge | 0.18–0.45 | slight blur |
| 5 | Cliff backdrop (authored outline per level) | 1.0 | sharp, low contrast |
| 6 | Traversable terrain (collision tiles) | 1.0 | sharp |
| 7 | Characters, cairns, markers | 1.0 | sharp |
| 8 | Foreground rock silhouettes | 1.25 | heavy blur |
| 9 | Weather: mist bands, dust or snow, gust streaks | screen / world | – |
| 10 | Grade and vignette | 0 | – |

Rules:

- Collision terrain is always the sharpest, highest-contrast layer.
- Foreground occluders never hide the climber's body for more than a moment,
  and never on a hazard.
- Blur layers (2, 4, 8) switch off in low-power mode.

### Target versus now

Now: the playable wall is procedural (tile-shaded rectangles, grain, holds) over
an authored backdrop polygon; background layers reuse existing painted PNGs.

Target: hand-painted tilesets for volcanic rock (solid, face, loose, ledge lip,
overhang), a painted cliff backdrop per section, and a Barranco-specific
mid-ground (the real valley's giant groundsels make a good original
silhouette). Painted at 2× the final pixel density, exported as transparent
PNG layers. Blender is optional for blocking layouts and baking light, never for
the final look.

## Light, weather, time

- Time of day comes from the expedition clock (`dayPhase`). Barranco is played
  in the morning.
- Weather risk drives mist opacity (0.08–0.5), gust frequency, and particle
  density.
- Planned: headlamp and campfire light pools (summit night, camps) as additive
  radial gradients. Lightning-free storms: flat light, low contrast, heavier
  haze.

## Typography and UI

- Existing families: **Fraunces** (display, italic field notes) and **Outfit**
  (body, labels). Keep them.
- In-scene HUD sits on a dark translucent scrim (`rgba(18,17,15,0.55)`) with
  light text. Sheets use the paper/ink theme.
- Kicker labels are uppercase, letter-spaced, 11 px. Titles are Fraunces 24 px.
- Every state shown in colour is also shown in words.

## Motion

- Camera eases toward the climber (about 4/s), looks ahead in the facing
  direction, and further up when climbing.
- Camera shake only on slips (strong) and gust onset (light), and never with
  reduced motion.
- No full-screen flashes.
