# Art direction

CLIMB UP should feel like a small party on a large mountain: a high view, layered ground, and a few readable figures. The references are the HD-2D look of modern pixel adventures, Zelda-like places to walk, and Oregon Trail decisions. The pictures in this repository are original to the project. Do not drop in frames, maps, or characters from those games.

## Palette

Paper and spruce are the interface. The mountain is a separate morning palette.

| Role | Color |
| --- | --- |
| Ink | `#1a1916` |
| Deep ink | `#12110f` |
| Paper | `#f3efe6` |
| Spruce | `#1f3d34` |
| Spruce ink | `#f4f1ea` |
| Barranco sky, top | `#f0ddc0` |
| Barranco haze | `#8ea8ab` |
| Barranco shadow | `#314047` |
| Ledge lip | `#d9c4a4` |

Type is Fraunces for titles and Outfit for labels. HUD labels stay light on the dark camp bar so they read over the sky.

## Figures

The party sprites are `pixel-you`, `pixel-lena`, `pixel-marco`, and `pixel-jun`: 43×96 pictures drawn around a 28×52 world box. They face by mirroring. A soft ellipse sits under the feet.

`presentPose` names idle, walk, scramble, rest, air, help, and fatigue. Every pose reports `frameCount: 1` and `fallback: 'single-image'`. Bob, squash, and lean move that one picture. They are not a sprite sheet. Do not describe them as frame animation until a sheet with real frames exists.

`climber-kneel.png` and the taller `climber-*.png` paintings are a different style. They stay out of the scramble so the party does not change medium mid-step.

## The Barranco picture

Back to front:

1. Morning sky gradient.
2. `far-mountains.png`, parallax 0.12.
3. `clouds.png`, three bands. Calm view freezes them.
4. `diorama-desert.jpg` for the valley, parallax 0.28. Barranco sits in the game's desert ground band.
5. A haze gradient.
6. Each ledge clips `ground-rock.png` so the transparent sky of that file is cropped off. A sand lip marks the walkable top.
7. Pixel tents, Marco until his decision, Lena, then you.
8. Wind streaks only after the wind hazard, and only when Calm view is off.
9. A darker `ground-rock.png` strip in front, parallax 1.15. Calm view omits it.

`foreground-snow.png` is the wrong biome for this camp. It is not used on the wall.

These layers are the current game art. Several are temporary plates. The valley image is a flat photograph-style plate, not modeled terrain. The ledge reuses one rock picture, cropped, rather than a drawn cliff with its own collision art. Label any new stand-in the same way: say what it is, and do not call a crop a finished environment.

## Shadows and weather

Shadows are one dark ellipse. There is no depth-of-field blur on the scramble. Time of day for this scene is morning only. Wind is a few streaks, not a particle system. Snow is not drawn here.

## UI

The scramble HUD is the camp bar, stamina, falls, Pause, and Calm. The line under the picture tells the player what to do. "A fictional scramble. Not a route." stays visible.
