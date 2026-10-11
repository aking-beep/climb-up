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
| Hop | Space / K / Z | A | JUMP |
| Climb (on rock), pull over (at the top) | ↑ / W | up | push the stick up, or tap CLIMB |
| Climb down, let go | ↓ / S | down | pull the stick down |
| Talk, read, help | E / Enter | X | the context button (TALK, READ, HELP) |
| Brace against the wind | Shift / B | shoulders | BRACE (hold) |
| Sit and rest (HOP gets you straight up and over) | R | Y | REST |
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

**The strategy is hard on purpose.** The engine is the Expo game's, kept
exactly (the parity test still holds); a trek layer on top
(`modes/expedition/engine/trek.gd`) adds:

- **A route and a permit.** The first card is the route: the long way
  (10 days), the steep way (8 days, starts higher, less food, harder days up)
  or the direct way (7 days, starts higher still, the hardest climbs). Every
  choice shows the hours it spends; when the days run out before the summit,
  the rangers walk you down.
- **Sickness, per person.** Altitude sickness when the party climbs faster
  than its nights allow or is worn out; a stomach bug when the water was not
  put on at camp; the cold, high at night with thin stores. It worsens going
  up and eases going down, with rest, or with Jun's care ("Jun treats"). You
  can send someone down early ("Send down"). At its worst it becomes an
  emergency card with only hard answers: everyone down, send them down with
  porters, or wait and see. Game fiction, not medical advice.
- **Different endings:** summit with all four, summit but not all of you,
  turned back together, a hard walk out, out of days, carried down, or the
  mountain kept the day.
- **Medicine.** The kit holds 3 doses on the long way, 2 on the steep
  way, 1 on the direct way. At camp a dose ("Medicine") eases someone's
  sickness a stage without Jun; before a climb a dose keeps your symptoms
  off for that climb.
- **Sleep and food.** A long stop that gives no energy back is a bad night;
  one that does is a good night. On thin stores (supplies under 30) the
  food can go bad and turn someone's stomach.
- **It reaches into the climbs** (`modes/expedition/engine/condition.gd`).
  The body you climb in is the one the camp choices left you, and the brief
  lists why:

  | At camp | On the climb |
  | --- | --- |
  | The party's health | where your health bar starts (lower again when unwell) |
  | A bad night | a smaller stamina bar, slower to get your breath back |
  | A good night | breath back a little faster |
  | Worn out (energy under 35) | a smaller bar |
  | Thin rations (supplies under 30) | slower to recover |
  | Altitude sickness | thinner air for you, and dizzy spells (half speed, your feet wander) |
  | A bad stomach | cramps that double you over (no walking or hopping for a second) |
  | The cold | numb fingers: holding on to rock costs more |
  | A dose of medicine before the climb | none of those symptoms, and +10 health |
  | A teammate sent down | not on the climb |
  | A steep route | more wind, faster stonefall |

  It also goes back the other way: health lost to thorns, ants and ravens
  on the climb costs the party health at camp (a fifth of it, up to 12).

Measured by the tests (8 seeds per row, climbs landed as completed):

| Route | careful | brisk (skips the rest days) | reckless (always up) |
| --- | --- | --- | --- |
| Long way | 8/8 summit together | 8/8 | 0/8 together (7 lost) |
| Steep way | 4/8 (rest days collide with the permit) | 8/8 | 0/8 (7 lost) |
| Direct way | 0/8 (out of days) | 7/8 | 0/8 (6 lost) |

**What the mountain throws at you.** Climbing problems in the spirit of
Mega Man stages or Metroid rooms, all along the walk, not only on the faces.

- **Hop** (SPACE, or JUMP on a phone): about two tiles up and two across.
  It costs breath (more in thin air), and a hop in a gust on open ground is
  a slip. Boulders on the path to hop, stream cuts and cracks to jump (miss
  and it is a fall), and stones that roll along the ground at you: hop them
  or step aside.
- **Your teammate's breath.** Someone you helped follows you, but walking
  drains their breath (more in thin air, more if they are unwell). When it
  runs out they sit down; go back and REST beside them. Walk off and leave
  them sitting, and Lena brings them instead: that counts as leaving them.

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
- **Health.** A red bar under stamina. Thorns, bites and beaks take it;
  at none left you collapse, which is a slip (back to the cairn, with some
  health back). After a hit you get a second's grace.
- **Thistles and nettles.** The spiny Kilimanjaro thistle on the tower, a
  stinging nettle in the Barranco valley. Walk into one and it stings
  (-10); hop over it.
- **Siafu.** A column of safari ants marching back and forth on a short
  stretch of ground. They bite (-8) and the bites cost breath; hop over.
- **White-necked ravens** circle over stretches of the path on every climb
  (the summit night has four). Stand about under one and it calls, then
  dives at the spot where you were: keep moving and it misses. A hit costs
  12 health and it flies off with one of your everlastings.
- **Water caches** give most of the stamina bar back, once per attempt.
- **Lost gear.** Three things per climb, hidden off the obvious line (an
  alcove up a side face, the back of a niche, a ledge up a pinnacle). Found
  gear stays found across attempts; the HUD and the camp screen count it.

**Always something to do, always something earned.**

- **Everlastings** (the papery Kilimanjaro flower) line the walkable ground:
  each is a breath back, they glint so the eye finds the next one, and the
  count shows at the top of the screen.
- **Fall and you drop them.** A slip that counts scatters every everlasting
  you are carrying back onto the ground where you found it: the count goes
  to 0 and you pick them up again on the next go. (Lost gear stays found.)
- **No length meter.** The HUD does not say how far along the climb you
  are; you see the next obstacle, not the distance left.
- **An obstacle every few steps.** `tools/levels/gauntlet.py` lines every
  walkable stretch with something to get past, roughly every six tiles (a
  second or two at a walk): a boulder to hop, a two-wide pit to jump,
  cracked slabs over a pit, or a short run of ice. It keeps them fair:
  nothing near a camp, cairn, rest stone, person or find, near a face you
  climb or land from, in a rolling stone's lane, on wind-exposed ground
  (the wind is the challenge there), right before an existing gap, or
  without room overhead to hop. Its rotation also places the creatures
  (a thistle or nettle, an ant column, a raven), and a second pass
  (`wildlife`) adds plants and ants where a boulder would not fit, with a
  full hop's headroom and six tiles between any two.
- **Stars at the top:** one for topping out, one for no slips that counted,
  one for three in four of the everlastings. The results card shows them
  and your best is kept; a three-star climb lifts the party at camp
  (+3 team, +2 energy).
- **Pacing is tested.** Every climb logs each moment the player has to act
  (a hop, a grab, a pull-over, a brace, a dodged stone, a cracked slab, a
  rolling stone, a step onto ice, a find, a cairn). The full-ascent tests fail if a climb
  has more than 5 s of walking with nothing to do, or more than 8 s of
  walking without a real challenge (flowers and cairns do not count as
  challenges). Climbing a face counts as play in itself. On the open
  stretches the gauntlet puts something in the way every second or two;
  the longest gaps left are around camps, cairns and people, where the
  ground is kept clear on purpose.

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
`tools/art/godot_creatures.py` (thistle, nettle, siafu, raven),
`tools/art/godot_kili.py` (diorama plates, map sprites, scenery from the
Expo game); sounds from `tools/audio/placeholders.py` (placeholders).

## Tests

```bash
godot --headless --path godot --import          # once, to build the import cache
godot --headless --fixed-fps 60 --path godot res://tests/runner.tscn
godot --headless --fixed-fps 60 --path godot res://tests/runner.tscn -- only=barranco
```

59 tests: the engine replaying seven expeditions recorded from the
TypeScript engine (178 steps, every state equal); the rules (stamina, wind,
climb consequences, outcomes land once, saves); the flow (a played choice
opens its climb without spending the card, back off at the brief, resume
from a cairn, a saved game plays on identically, the screens build); and all
three climbs played start to finish by a scripted climber through the real
input actions with every hazard live (the bot reads the same warnings a
player sees), each hazard on its own (slabs hold a walker and drop someone
who stops, a stone is announced before it falls, ice slides, water and gear,
walking costs more breath on the summit), plus the order of difficulty and
that every find stands on reachable ground. `test_body` covers the
creatures (a hop clears a thistle, ants bite and cost breath, a raven hits
someone standing still and misses someone who moved, no health left is a
slip) and the camp reaching into the climb (a bad night, hunger and
altitude sickness shrink the bar, slow recovery and bring dizzy spells; a
dose keeps them off; a bad stomach brings cramps, the cold costs grip; what
hurt you on the climb costs the party; sleep and medicine at camp).

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
