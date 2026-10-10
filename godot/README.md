# CLIMB UP: Godot prototype

The Barranco Wall as a side-scrolling mountaineering adventure, built in
Godot 4 alongside the Expo app (which it does not touch). Why and how:
[architecture](../docs/godot-migration/architecture.md) and
[comparison with Expo](../docs/godot-migration/comparison.md).

## Run it

1. Install **Godot 4.4 or newer** (standard build, not .NET) from
   godotengine.org.
2. Open the editor, **Import**, choose `godot/project.godot`.
3. Press **Play** (F5). The game starts on the title screen.

Landscape, 480 × 270 pixel-art viewport scaled to the window.

| Action | Keys | Gamepad | Touch |
| --- | --- | --- | --- |
| Walk | ← → / A D | d-pad, left stick | pad |
| Climb (on rock), pull over (at the top) | ↑ / W | up | ▲ |
| Climb down, let go | ↓ / S | down | ▼ |
| Talk, read, choose | E / Space / Enter | A | ACT |
| Brace against the wind | Shift / B | shoulders | BRACE |
| Sit and rest | R | Y | REST |
| Pause (turn back, settings, save and quit) | Esc / P | Start | II |

Touch controls appear automatically on phones; the pause menu toggles them.

## The climb

Barranco Camp (talk to Lena and Jun, read the signs) → the approach under
the buttress → a scramble band → the first face → a traverse over a void →
the rest ledge → a steeper face → the exposed ledge (brace in the gusts) →
Marco, stuck: help him, leave him for Lena, or step back → the loose gully
(rest in the niche halfway) → the shoulder and the view → the crouch ledge
in the wind → the upper face → the plateau → Karanga.

Slips send you back to the last cairn; three end the attempt. Turning back
is always in the pause menu. The outcome lands on the expedition once, with
the same numbers as the Expo game's Barranco policy, and quitting mid-wall
resumes at the last cairn.

## Layout

```
core/      shared systems: player, climbing, world, weather, camera,
           companions, input, audio, save, settings, ui
modes/expedition/
           the expedition prototype: state, flow screens, levels/
tests/     headless test runner and suites; shot/demo tools
```

The level is `modes/expedition/levels/kilimanjaro/barranco/barranco.txt`,
stamped by `tools/levels/barranco_map.py`. Art comes from
`tools/art/godot_barranco.py` (tiles, props) plus the shared party sheets
and scenery; sounds from `tools/audio/placeholders.py` (placeholders).

## Tests

```bash
godot --headless --path godot --import          # once, to build the import cache
godot --headless --fixed-fps 60 --path godot res://tests/runner.tscn
godot --headless --fixed-fps 60 --path godot res://tests/runner.tscn -- only=barranco
```

22 tests: the rules (stamina, wind, outcome shape, expedition consequences,
saves), the expedition flow (outcome lands once, resume from a cairn,
screens, quality never changes the climb), and the level played by a
scripted climber through the real input actions, start to finish.

Tools (need a display; under Linux CI use `xvfb-run`):

```bash
godot --path godot --rendering-driver opengl3 res://tests/shot.tscn -- out=/tmp/shot at=20,91 at=66,41
godot --path godot --write-movie /tmp/climb.avi --fixed-fps 30 res://tests/demo.tscn
```

## Placeholders and gaps

- **Audio** is synthesized placeholder (see `assets/audio/README.md`). No music.
- **Animation** reuses the side-view sheets; missing frames for a real
  mantle, scramble, traverse, crouch-walk, and a two-person help-up
  (`help` is one pose). Wanted: hand-drawn sheets with those clips.
- **Tiles and props** are generated, not hand-finished.
- **Weather** has wind only; the `Weather` states (fog, rain, snow) are
  designed in the architecture doc, not built.
- **Export**: no Android, iOS or web export has been made. Nothing has run
  on a phone.
