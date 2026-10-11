# CLIMB UP: Godot prototype

The whole Kilimanjaro expedition in Godot 4, built alongside the Expo app
(which it does not touch): the strategy game at camp, ported from the Expo
engine and checked against it, and three climbs you play as a
side-scrolling adventure. Why and how:
[architecture](../docs/godot-migration/architecture.md) and
[comparison with Expo](../docs/godot-migration/comparison.md).

## Run it

- **In a browser:** the web build is published as a private artifact
  (desktop, or a phone held sideways). Built with `tools/godot/export.sh web`.
- **On Android:** install the debug APK built by
  `tools/godot/export.sh android` (arm64, about 30 MB). Allow installs from
  unknown sources for the app you open it with.
- **In the editor:** install **Godot 4.7 or newer** (standard build, not
  .NET), **Import** `godot/project.godot`, press **Play** (F5).
- **iOS:** not built. It needs the Godot editor on a Mac with Xcode
  (Project > Export > iOS).

Landscape. The view is about 270 pixels tall, drawn at a whole-number
scale (3× on a 1080p window, 4× on most phones) and widened to fill the
screen, so pixel art stays sharp with no black bars.

| Action | Keys | Gamepad | Touch |
| --- | --- | --- | --- |
| Walk (analog on the stick) | ← → / A D | d-pad, left stick | left thumb, anywhere on the left half |
| Climb (on rock), pull over (at the top) | ↑ / W | up | push the stick up, or tap CLIMB |
| Climb down, let go | ↓ / S | down | pull the stick down |
| Talk, read, help | E / Space / Enter | A | the context button (TALK, READ, HELP) |
| Brace against the wind | Shift / B | shoulders | BRACE (hold) |
| Sit and rest | R | Y | REST |
| Pause (turn back, settings, save and quit) | Esc / P | Start | II |

Touch controls appear automatically on phones; the pause menu toggles them.
Grabs, slips and gusts buzz the phone (off with reduced motion). Walking
never carries you off a drop: you stop at the edge, and walking onto a face
from a ledge grabs it.

## The game

**At camp** (the strategy half): the diorama shows where the party is, the
time of day and who is struggling; the paper shows the day's decision card
from the Expo game, the camp beats (pole pole, water, head count), the
party (sit with someone who is down), and what the last decision did. At
the end it becomes the scorecard. Cards and rules are the Expo game's, run
by a GDScript port of its engine (`modes/expedition/engine/`).

**The three climbs** (the playable half), launched by the choice that
leaves their camp, easiest first:

| Climb | From | Asks | Teammate |
| --- | --- | --- | --- |
| Lava Tower | Shira 2 | scramble, a loose scree face, a windy ledge, a chimney; 4 slips allowed | none |
| Barranco Wall | Barranco | the full wall below; 3 slips | Marco |
| Summit night | Barafu, by headlamp | five frozen switchbacks, the cold halves recovery, a long windy rim, Stella Point at dawn; 2 slips | Jun |

Each starts with a brief; backing off there (or turning back later) is a
retreat that costs the day, not the expedition. The outcome lands once.

**What the mountain throws at you.** No jumping: these are climbing
problems, in the spirit of Mega Man stages or Metroid rooms.

- **Thin air.** Walking costs breath, a little at the tower, more on the
  summit, and more again for a party that has not acclimatized at camp.
  Uphill costs more than flat; standing still and sitting recover.
- **Stonefall.** Stones come down set chutes. Grit trickles over the column
  a stone is about to fall in; move across to another column, or wait
  under rock. A hit is a slip (a helped teammate can still catch it).
- **Cracked slabs.** Pale, cracked stones that hold you while you keep
  walking. Stop on one, or brace on one in a gust, and it drops you. They
  settle back after a while.
- **Ice** (summit night). Little grip: you slide, and the edge guard cannot
  hold you on ice. On the fourth switchback the ice runs up to a crevasse,
  crossed on a band of rock.
- **Water caches** give most of the stamina bar back, once per attempt.
- **Lost gear.** Three things per climb, hidden off the obvious line (an
  alcove up a side face, the back of a niche, a ledge up a pinnacle). Found
  gear stays found across attempts; the HUD and the camp screen count it.

| Climb | Hazards | Lost gear |
| --- | --- | --- |
| Lava Tower | a scree bridge of cracked slabs, stonefall down the chimney (a niche halfway up to shelter), the windy lip | on the windy lip, in the chimney niche, on a ledge beyond the tower |
| Barranco Wall | stonefall down the loose gully, cracked slabs on the exposed ledge where you brace | an alcove above ledge 2, the back of the gully niche, a ledge on the plateau |
| Summit night | ice on two switchbacks, the crevasse, stonefall on two rock steps, cracked slabs on the windy rim, thin air | a pocket off two switchbacks, a ledge above the rim |

## The Barranco Wall

Barranco Camp (talk to Lena and Jun, read the signs) → the approach under
the buttress → a scramble band → the first face → a traverse over a void →
the rest ledge → a steeper face → the exposed ledge (brace in the gusts) →
Marco, stuck: help him, leave him for Lena, or step back → the loose gully
(rest in the niche halfway) → the shoulder and the view → the crouch ledge
in the wind → the upper face → the plateau → Karanga.

Slips send you back to the last cairn; three end the attempt. Turning back
is always in the pause menu. Quitting mid-climb resumes at the last cairn.

## Layout

```
core/      shared systems: player, climbing, world, weather, camera,
           companions, input, audio, save, settings, ui
modes/expedition/
           expedition.gd (the running game), engine/ (the port of the
           Expo engine), data/ (Kilimanjaro, exported from Expo), camp/
           (the strategy screen), levels/ (ClimbLevel and the three climbs)
tests/     headless test runner and suites; shot/demo tools
```

Levels are ASCII maps stamped by `tools/levels/barranco_map.py` and
`tools/levels/kili_maps.py`. Card content comes from the Expo source via
`tools/godot/export_content.ts`, which also records scripted playthroughs
of the TypeScript engine for the parity test. Art: `tools/art/godot_barranco.py`
(tiles, props), `tools/art/godot_backwalls.py` (rock strata),
`tools/art/godot_hazards.py` (ice, slabs, stones, water, gear),
`tools/art/godot_kili.py` (diorama plates, map sprites, scenery from the
Expo game); sounds from `tools/audio/placeholders.py` (placeholders).

## Tests

```bash
godot --headless --path godot --import          # once, to build the import cache
godot --headless --fixed-fps 60 --path godot res://tests/runner.tscn
godot --headless --fixed-fps 60 --path godot res://tests/runner.tscn -- only=barranco
```

39 tests: the engine replaying seven expeditions recorded from the
TypeScript engine (178 steps, every state equal); the rules (stamina, wind,
climb consequences, outcomes land once, saves); the flow (a played choice
opens its climb without spending the card, back off at the brief, resume
from a cairn, a saved game plays on identically, the screens build); and all
three climbs played start to finish by a scripted climber through the real
input actions with every hazard live (the bot reads the same warnings a
player sees), each hazard on its own (slabs hold a walker and drop someone
who stops, a stone is announced before it falls, ice slides, water and gear,
walking costs more breath on the summit), plus the order of difficulty and
that every find stands on reachable ground.

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
- **Export**: web and Android (debug) builds exist. They were checked in
  desktop Chromium and in Chromium emulating a phone (touch stick,
  landscape, menu → camp → cards → the Lava Tower), **not on a real
  phone**: thumb feel, haptics and frame rate are unmeasured. No iOS build. The APK is debug-signed, not for
  the Play Store.
- **Only Kilimanjaro.** Everest and the other mountains in the Expo app
  are not ported.
