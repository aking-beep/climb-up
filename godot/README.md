# CLIMB UP: Godot prototype

Two games on one climbing engine, in Godot 4, built alongside the Expo app
(which it does not touch). The title screen picks one:

- **Expedition:** the whole Kilimanjaro trip: the strategy game at camp,
  ported from the Expo engine and checked against it, and three climbs you
  play as a side-scrolling adventure.
- **Crag:** single sport routes at one cliff, graded 4 to 6c, nothing to do
  with the expedition (its own menu, levels, progress and save file). See
  [The crag](#the-crag). Why and how:
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

Touch controls appear automatically on phones; the pause menu toggles them,
and has a "Show FPS" readout for playtests ([the checklist](../docs/playtest-checklist.md)).
Grabs, clips, slips and gusts buzz the phone; "Vibration" in either pause
menu turns that off (on its own, apart from reduced motion; Android needs
the VIBRATE permission, which the export preset asks for). When the app
goes to the background, the phone locks, or the browser tab or window loses
focus, a climb pauses under its pause menu (and the expedition saves where
the climb is, so a killed app resumes there). The Android back button
opens the pause menu on a climb and goes back a screen on the menus.
Screens change with a short fade (instant with reduced motion). Walking
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
  (10 days), the steep way (9 days, starts higher, less food, harder days up)
  or the direct way (8 days, starts higher still, the hardest climbs). When
  the days run out before the summit, the rangers walk you down.
- **Every choice shows what it will cost before you pick it**
  (`Trek.foresee`): the hours, the stats it moves (the route's toll on the
  way up included), and a risk band (low, medium, high) with its reasons:
  the body not ready for the next height, tired legs, a steep route, the
  weather, someone already unwell, the end of the permit. A band, not a
  number: what happens still rolls on the day.
- **Sickness, per person.** Altitude sickness when the party climbs faster
  than its nights allow or is worn out; a stomach bug when the water was not
  put on at camp; the cold, high at night with thin stores. It worsens going
  up and eases going down, with rest, or with Jun's care ("Jun treats"). You
  can send someone down early ("Send down"). At its worst it becomes an
  emergency card with only hard answers: everyone down, send them down with
  porters, or wait and see. Game fiction, not medical advice.
- **Someone who goes down is gone for the rest of the trip.** They say
  goodbye (Marco wants a photo from the top), and every camp after has a
  line about the gap they left, a different one each camp. Their camp beat
  goes with them (no pole pole without Lena, no head count without Jun, no
  "Jun treats"). A smaller party is never whole again: team condition tops
  out 8 lower per person gone. With Lena gone, a teammate you leave on a
  climb has no one to bring them up: they turn back down for good. The
  climb brief and the ending name who is missing.
- **Different endings:** summit with all four, summit but not all of you,
  turned back together, a hard walk out, out of days, carried down, or the
  mountain kept the day.
- **Medicine that fits the illness.** The kit holds 3 doses on the long
  way, 2 on the faster way, 1 on the fastest. At camp the button names what
  it gives: a painkiller (like Tylenol) for altitude sickness eases the
  headache and keeps the dizziness off the next climb, but does not cure
  it (only rest or going lower does, and the game says so); stomach pills
  settle a stomach; the cold needs a hot drink and dry gloves (food, not
  a dose). Before a climb, the brief offers the same.
- **Why, in plain words.** Each sick person's row says what they have, why
  (the team went up faster than their body could adjust; the water wasn't
  boiled; the food went bad; a freezing night), and what helps. Someone
  who is exhausted says so, and why they shouldn't go higher today.
- **Sleep and food.** A long stop that gives no energy back is a bad night;
  one that does is a good night. On very thin stores (supplies under 20)
  the food can go bad and turn someone's stomach.
- **It reaches into the climbs** (`modes/expedition/engine/condition.gd`).
  The body you climb in is the one the camp choices left you, all of it in
  the one stamina bar (how big it is, how fast it refills), and the brief
  lists why:

  | At camp | On the climb |
  | --- | --- |
  | The party's health (under 80) | a smaller bar, down to 70% at none |
  | Being unwell at all | a smaller bar (10% per stage) |
  | A bad night | a smaller stamina bar, slower to get your breath back |
  | A good night | breath back a little faster |
  | Worn out (energy under 35) | a smaller bar |
  | Thin rations (supplies under 30) | slower to recover |
  | Altitude sickness | thinner air for you, and dizzy spells (half speed, your feet wander) |
  | A bad stomach | cramps that double you over (no walking or hopping for a second) |
  | The cold | numb fingers: holding on to rock costs more |
  | A dose of medicine before the climb | none of those symptoms |
  | A teammate sent down | not on the climb |
  | A steep route | more wind, faster stonefall |

  It also goes back the other way: stamina lost to thorns, ants and ravens
  on the climb costs the party energy at camp (a fifth of it, up to 12),
  and energy is what sets the size of the next climb's bar.

Measured by the tests (8 seeds per row, climbs landed as completed):

| Route | careful | brisk (skips the rest days) | reckless (always up) |
| --- | --- | --- | --- |
| Long way | 8/8 summit together | 7/8 | 0/8 together (7 lost) |
| Steep way | 8/8 | 8/8 | 0/8 (7 lost, 1 carried down) |
| Direct way | 8/8 | 8/8 | 0/8 (5 lost, 2 carried down) |

Care wins on every route and haste never brings everyone home; the short
routes are tighter (fewer stores, harder climbs, more sickness), not closed
to a careful party. The test fails if care drops under 4/8 on a short route.

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
- **One bar: stamina.** Everything that hits you takes stamina, the same
  bar walking and climbing spend. A hit you have no stamina left for is a
  collapse, which is a slip (back to the cairn). After a hit you get a
  second's grace.
- **Thistles and nettles.** The spiny Kilimanjaro thistle on the tower, a
  stinging nettle in the Barranco valley. Walk into one and it stings
  (-10 stamina); hop over it.
- **Siafu.** A column of safari ants marching back and forth on a short
  stretch of ground. They bite (-12 stamina); hop over.
- **White-necked ravens** circle over stretches of the path on every climb
  (the summit night has four). Stand about under one and it calls, then
  dives at the spot where you were: keep moving and it misses. A hit costs
  12 stamina and it flies off with one of your everlastings.
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

## The crag

`modes/crag/`: Lion Rock. First a lesson, **First Climb**: a short route
where the game stops the first time each new thing comes up (the rock, a
bolt, the rest on the rope, tiny holds, a big hold, a jump) and explains
it, until you tap "Got it". Then six routes, easiest first; each opens when the
one before it is finished. The words on screen are for non-climbers (tiny
holds, big holds, a jump for a far hold), with the climbing name after.

Three things describe a route, apart from each other, as on a real cliff:

- **The grade** is how hard the moves are: each route is taller, with more
  stretches of tiny holds, fewer big holds, and a grip that fades faster.
- **The bolting** is how far apart the bolts are: well bolted (gaps up to
  3.5 m), sporty (up to 6 m) or run-out. It is set per route, not by the
  grade: the 5b is sporty, the 6a and the 6c roof are well bolted.
- **The exposure** is how far a fall can go: twice your height above the
  last bolt plus slack, and whether a fall low down can reach the ground
  (a high first bolt, or a long way to the second).

The brief and the route list show all three (`Crag.facts()` works the
bolting and exposure out from the map). Rows are half a metre.

| Grade | Route | Height | Bolts | Gaps (rows) | Bolting | Exposure | Also |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Lesson | First Climb | 11 m | 3 | 7, 7 | well bolted | medium | everything once, explained |
| 4 | Warm-up Wall | 14.5 m | 6 | 4, 4, 5, 4, 4 | well bolted | low | |
| 5b | Sundown Traverse | 19.5 m | 4 | 6, 10, 12 | sporty | high, ground-fall risk | a long traverse, a high first bolt |
| 6a | The Pinch | 21 m | 8 | 5, 5, 5, 4, 5, 5, 5 | well bolted | low | the longest crimps at the top |
| 6b | Leap of Faith | 25.5 m | 6 | 4, 7, 8, 11, 12 | sporty | high | a dyno |
| 6c | Lion's Roof | 25 m | 8 | 5, 5, 4, 7, 7, 7, 7 | well bolted | medium | a traverse under a roof, a dyno |
| 7a | Thunderhead | 29 m | 5 | 7, 10, 14, 17 | run-out | high, ground-fall risk | two dynos, a roof |

- **Read the route first.** The brief offers "Look at the route first":
  the camera runs up the line from the ground with the tiny holds, big
  holds, blank rock to jump, every bolt and the long run-outs marked.
  A tap skips it. Looking is free (it does not spoil an onsight), and it
  is in the pause menu too.
- **Beta.** "Ask for beta" gives tips worked out from the route (which
  bolts to clip from a big hold, which sit on tiny holds, where the
  run-outs and jumps are). Taking it turns a clean first go into a flash.
- **Pick your shoes.** Before every route (not the lesson) you choose:
  neutral shoes (comfy and flat: you climb at three quarters of the speed,
  and the rock costs 30% less stamina) or aggressive shoes (tight and bent:
  30% faster, 35% more stamina). Neutral suits a long, pumpy route you want
  to rest through; aggressive gets you past the hard bits and to the top
  quicker. The game remembers your last pick and offers it first. In the
  tests both pairs send the 6a and the 7a; aggressive is about 30% quicker,
  neutral tops out with more stamina left.
- **Tap to clip.** At each bolt the game asks "Clip in?": one tap of CLIP,
  on every route. Where you clip from is the skill: one hand off a big hold
  (jug) is free, off ordinary rock costs 2 stamina, off tiny holds (crimps)
  costs a third of your grip and 4 stamina times (1 + the route's grip
  drain), so about 6 on the 6a and 8 on the 7a. The hint says what the
  clip will cost from where you are, and on tiny holds suggests climbing
  to a big hold first. A clip snaps in with a click and a bell, and the
  quickdraw jumps; after a long run-out (9 rows or more) it reads
  "Clipped! Rest bar full." with a chime. Climb on without clipping and
  the bolt stays unclipped: a fall then drops you to the last one you did
  clip, and the game tells you so. The rope runs up through every clipped
  bolt to you.
- **Rest on the rope.** Every clip (and every fall the rope catches) fills
  a green rest bar over your head.
  Once clipped, the big button reads REST whenever nothing else needs a
  tap: tap it to sit back on the rope and get stamina back from the bar
  (20 per bolt). Rest as often as you like; moving ends a rest and the
  rest of the bar waits. Where the bolts are far apart you rest on the big
  holds (jugs) too.
- **Grip on tiny holds.** Tiny holds (crimps) burn stamina. A grip meter
  over your head fades slowly while you keep moving and fast if you stop
  (both faster the harder the route). Squeeze GRIP when it drops: each
  squeeze is a puff of chalk and +45% grip, and squeezes closer together
  than 0.2 s do nothing more, so mashing is no better than a squeeze in
  time. A grip kept above about half costs little; a slack one burns well
  over the normal rate. Measured with the test bot squeezing below half:
  0 to 6 squeezes a route (6 on the 7a), where the old meter needed about
  four taps a second on every stretch of tiny holds.
- **Stick the jump.** After a dyno you have a second to tap GRIP three
  times, or the hold slips out of your hands.
- Pausing, or a lesson, while on the rock keeps you on the rock.
- On a phone the crag has one big tap button (it reads CLIMB, CLIP or
  GRIP) beside JUMP, and no BRACE or REST.
- **Lead climbing.** You start on the ground with a belayer. A fall is
  twice as far as you were above the last bolt you clipped, plus slack: a
  rope whoosh, then you hang on the rock below the bolt and the game says
  how far you fell. Fall before the first bolt, or far enough above a low
  one, and you hit the ground: a thump, 25 stamina, and back to the foot
  of the cliff (bolts you clipped stay clipped). Five falls on the easy
  routes, three on the hardest, and you have to come down.
- **The holds.** Ordinary rock; crimps (chalked edges) that empty the arms
  fast, worst if you stop on them; jugs (big holds) where hanging gives
  the arms back. Stamina is the one bar, as on Kilimanjaro.
- **The dyno.** Blank rock with holds out of reach above: JUMP on the rock
  (aim with the stick) and the hands catch the first hold they reach. It
  costs a hard move's stamina. Miss and you drop back to the holds you
  left.
- **Style.** Reach the anchor and the route is done: onsight (first go,
  no falls, no beta), flash (first go, no falls, with beta), redpoint (no
  falls, after earlier goes), or "top, with falls" (not a clean ascent).
  A go counts when you tie in, not when you open the brief. Lowering off
  keeps your high point (the most bolts clipped), shown in the route list.
  The best per route is kept (`user://climb_up_crag.json`); a save with
  wrong types loads as defaults rather than breaking.
- **Moves.** Climbing goes hold to hold: each reach is a move with its own
  sound (sharper on tiny holds); the results count them.
- **Maps** come from `tools/levels/crag_maps.py`, written bottom to top as
  segments (rock, crimps, jug, blank, traverse); holds, quickdraws and
  the anchor from `tools/art/crag_hd.py`, drawn smooth (see "Look").
- **Gear you can see.** Quickdraws are a steel hanger, a bright blue sling
  and two carabiners (the rope shows through the bottom one once clipped),
  shown a little larger than life; the bolt in reach glows. The rope is a
  round, shaded orange line with a dark outline, sagging between bolts.

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
## Look

Drawn for phones, in the spirit of the best-looking mobile games (the
chunky, outlined Supercell characters; Alto's layered gradients and soft
far layers): everything is painted at 4x and shown at a quarter scale with
smooth filtering and mipmaps (the project default), so a phone draws it at
its own resolution instead of blowing up pixels. One colour grade on top.

- **Smooth terrain** (`tools/art/terrain_hd.py` → `assets/terrain/hd/`):
  rock, back wall and faces with soft bevels and cracks, edges with rounded
  grass, moss or snow caps, slopes, scree, boulders, holds, ice and slabs.
  `TerrainTiles.paint_hd` lays them as scaled layers (`BackHD`, `GroundHD`,
  `EdgesHD`) over the 16 px layers, which are hidden but keep the
  collision. Without the HD files the pixel layers show as before.
- **Smooth props** (`tools/art/props_hd.py` → `assets/terrain/props/hd/`):
  cairns, signs, plants, tents, fire, stones, gear and creatures.
  `Art.tex(path)` loads the HD file but reports the pixel size, so regions
  and positions in code stay in world pixels.
- **The harness.** Every climber wears one: a red waist belt with a belay
  loop, leg loops, quickdraws on the gear loop and a chalk bag.

The pixel sources below remain as the fallback and as the collision grid:

- **Rock** (`tools/art/godot_rock.py`) is drawn the way pixel artists draw
  rock, not as noise: blocks (a tileable Voronoi stretched along the
  bedding), each one a flat cluster lit by how it faces the upper-left
  light, with a lit rim, a shadowed edge and a crack between blocks, a slow
  swell of light and dark so the tiling never shows, and hue-shifted ramps
  (cool shadows, warm lights). Per climb palette (Barranco basalt, Lava
  Tower red, summit blue-grey): solid rock, a darker flatter back wall (it
  is further away), and climbable faces lighter and warmer with vertical
  joints, so the way up reads at a glance.
- **Edges** are an overlay on the same rock, so edge and interior are one
  surface: a warm lit lip with moss (snow on the summit), an outline and
  an undercut shadow below, shaded sides, bevelled corners. Slopes, scree,
  boulders and face holds come from the same palettes.
- **People** (`tools/art/characters_hd.py`) are drawn as clean illustrated
  characters (round shapes, a big readable head, big hands and boots, cel
  shading, a warm rim light, a bold outline) at 4x and shown at a quarter scale, smooth, with
  mipmaps: a phone draws them at its full resolution. Same poses and frame
  layout as the pixel sheets (`tools/art/characters.py`), which remain as
  the fallback.
- **The lens** (`core/world/grade.gdshader`) grades the world under the
  HUD: shadows toward a cool tint and lights toward a warm one per climb,
  a little more contrast and colour, and a vignette. "Low power" keeps the
  vignette only (no screen read).

`tools/levels/kili_maps.py`. Card content comes from the Expo source via
`tools/godot/export_content.ts`, which also records scripted playthroughs
of the TypeScript engine for the parity test. Art: `tools/art/godot_barranco.py`
(props, fallback tiles), `tools/art/godot_rock.py` (rock, edges, faces),
`tools/art/characters_hd.py` and `tools/art/crag_hd.py` (people and gear),
`tools/art/terrain_hd.py` and `tools/art/props_hd.py` (smooth terrain and props),
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

89 tests: the engine replaying seven expeditions recorded from the
TypeScript engine (178 steps, every state equal); the rules (stamina, wind,
climb consequences, outcomes land once, saves); the flow (a played choice
opens its climb without spending the card, back off at the brief, resume
from a cairn, a saved game plays on identically, the screens build); and all
three climbs played start to finish by a scripted climber through the real
input actions with every hazard live (the bot reads the same warnings a
player sees), each hazard on its own (slabs hold a walker and drop someone
who stops, a stone is announced before it falls, ice slides, water and gear,
walking costs more breath on the summit), plus the order of difficulty and
that every find stands on reachable ground. `test_crag` leads all seven
crag routes to the anchor with a scripted climber (walk to the line,
traverse where it goes, rest on jugs, keep moving on crimps and squeeze
only when the grip drops below half, dyno, pull over), prints the taps
each route took by kind, and checks the rules one at a time: crimps drain
and jugs give back, a lead fall is twice the height above the bolt and a
low one reaches the ground, a dyno crosses the blank, grip wants squeezes
not mashing, grade, bolting and exposure are apart, reading the route and
beta (a flash), styles, high points, unlocks, a go counts at tie-in, and
a bad save loads safely. `test_platform` covers the phone: going to the
background mid-climb pauses (and saves the expedition), the back button,
vibration as its own setting, a bad settings file, panels that fit and scroll on a short screen. `test_pacing` covers
the expedition fixes: a regroup does not bring down an hour of stones at
once, no stone starts on the climber, the brief names the cost of a slip
at camp and leaves out a teammate who has gone down, the last slip says
the climb is over. `test_body` covers the
creatures (a hop clears a thistle, a sting or a bite is stamina gone, a
raven hits someone standing still and misses someone who moved, a hit with
no stamina left is a slip, poor party health is a smaller bar) and the camp reaching into the climb (a bad night, hunger and
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
