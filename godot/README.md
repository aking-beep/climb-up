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
| Sit and rest; also how you sit out a gust (HOP gets you straight up and over) | R / Shift | Y, shoulders | REST |
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
| Summit night | Barafu, by headlamp | five frozen switchbacks, the cold slows recovery, a long windy rim, Stella Point at dawn; 2 slips | Jun |

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

  Before each climb the brief shows this as rows, each a green or red
  chip with the numbers the climb will use (`Condition.report`): the bar
  (what the team's energy gives and what took a share of it), breath
  (how much more walking costs at this height, and whether the party is
  used to it), rest (how fast sitting down refills it: the cold, sleep,
  food) and any illness with the medicine for it. The choices stay pinned
  under the brief, so Start is always on screen.

  The thin air rises gently with height (`StaminaModel.height_factor`:
  about +15% for every 500 m above 4,000 m, never more than +60%), and a
  party not yet used to the height pays up to two thirds more on top. A
  full bar lasts at least 30 s of walking uphill on every climb for a
  rested party; the summit is still the hardest breathing, about half as
  long again as low down for a party that rushed (`test_rules`).

  **Three climbs, easy to hard.** The Lava Tower is the easy one, the
  Barranco Wall the middle (drain 0.9, rest at 95%, fewer animals, no
  rolling stone by the exit), the summit night the boss (drain 1.1, rest
  at 80%, two slips, the cold and the thinnest air). On a played climb the
  bar is never smaller than 48 (`ClimbLevel.MIN_BAR`): every face fits in
  it, so even the summit is possible for a worn-out party that rests to
  full before each face (test_climbs). A tired party (bar 54) gets up the
  Barranco Wall without running dry (test_barranco).

  **Only REST gives breath back.** On the mountain, standing still and
  walking never refill the bar (`StaminaModel.still_recovers` is off on the
  climbs; the crag keeps its standing shake-out). REST does: 22 a second,
  30 on a rest stone, scaled by the cold and by what camp did (sleep, food,
  sickness). Every obstacle costs: walking, more uphill, a hop, ice,
  climbing rock, standing in a gust (test_expedition_rules).

  **Two rests a cairn, then camp food.** REST fills you up at most twice
  between two cairns (`ClimbLevel.REST_LIMIT`). A rest lasts until you are
  full, so getting up to dodge a stone and sitting again is the same rest.
  Reaching the next cairn, or being sent back to one, gives both back. Out
  of rests, a sit eats a snack from the camp's food: 3 supplies
  (`ClimbLevel.SNACK`), taken off the expedition's supplies when the climb
  lands, and gone for the rest of the trip. With no food to spare, sitting
  gives nothing back. A rest stone never counts, and neither does sitting
  out the wind on exposed ground, which keeps you safe but gives no breath
  back (a little with the goggles and buff). The HUD shows "Rests 2", then
  "Rests 0 (food N)"; the brief and the results say what was eaten. The
  test bots eat nothing on the tower or the wall and one snack on the
  summit night.

  **No brace button: REST in the wind.** On exposed ground a gust cannot
  take someone sitting down. The warning says "don't move, REST"; moving in
  a gust is still a slip, and standing in one nudges you and costs breath.
  Sitting on windy ground gives nothing back (6 a second with the goggles
  and buff). The Barranco Wall's shoulder is easier: its open stretch is 6
  tiles instead of 10, with longer calms between gusts.

  **Gear makes a climb easier.** Each climb hides three pieces, each
  before what it helps with:

  | Gear | What it does |
  | --- | --- |
  | Trekking poles | walking and uphill cost 30% less |
  | Gloves | rock costs 20% less |
  | Goggles and a buff | a gust pushes and costs 60% less; sitting on windy ground gives some breath back |
  | Crampons | no sliding on ice, and ice costs half |
  | Headlamp | the cold and the dark no longer slow your walk |

  Gear lasts the attempt (and a save and resume). Fall into a hole, or
  lose the climb, and you start again with none: it is back where you
  found it. The brief lists what is hidden; the HUD counts it; the results
  say what you carried.

  **Camp gives energy back** (`Trek.camp_recovery`): a night's sleep gives
  about 10 low down, 6 at 4,600 m, less hungry or ill, almost double on a
  rest day, half after a big push up; and the porters stretch the food (a
  share of each day's supplies comes back: 40% on the long way, 30% and
  20% on the faster ones). A careful party now reaches every climb with
  stamina for it and gets home on all three routes; a reckless one on the
  fastest route still does not (test_trek).

  **The weather** (`core/world/climate.gd`, each level's `climate`). Every
  climb has its own day, moved along by how far up the route you are and
  by the clock: the Lava Tower from hot afternoon sun on black rock (27°C)
  to a cold sunset at the top, the Barranco Wall from a sunny valley into
  cloud, the summit night from -7°C to -16°C before dawn and a pink sunrise
  at Stella Point, the way down from frost into the heat. Below 5°C you
  walk slower (up to 15%; climbing speed is not slowed, so a face never
  costs more than a bar) and resting works less (up to 20%);
  above 24°C every move costs more (up to 15%). The light over the scene
  shifts with it, the HUD shows the temperature in degrees and words, and
  the brief has a Weather row.

  **Falls are never a mystery.** Grabbing a face your stamina will not get
  you up says so ("This face takes about 26 stamina and you have 8").
  Empty arms on a Kilimanjaro face hang on for 3 s with a warning, time to
  climb down; if they let go, the slip says your arms gave out. Every slip
  names its cause (a stone, a long fall, the wind, your arms). A fall into
  a hole (the gaps that drop out of the bottom of the map) is the worst:
  it counts as a slip and you start the climb again from the beginning.
  Loose rock costs a third more, not 60%.

  **Wildlife along the whole walk.** Thistles, ants and ravens are spread
  one per stretch of the route, start to finish
  (`tools/levels/gauntlet.py` `SPREAD`), not bunched on one bench.

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
  Uphill costs more than flat. Only sitting down (REST) recovers.
- **Stonefall.** Stones come down set chutes. Grit trickles over the column
  a stone is about to fall in; move across to another column, or wait
  under rock. A hit is a slip (a helped teammate can still catch it).
- **Cracked slabs.** Pale, cracked stones that hold you while you keep
  walking. Stop on one, even to sit out a gust, and it drops you. They
  settle back after a while.
- **Ice** (summit night). Little grip: you slide, and the edge guard cannot
  hold you on ice (unless you found the crampons). On the fourth switchback the ice runs up to a crevasse,
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
- **Gear.** Three pieces per climb, hidden off the obvious line (an
  alcove up a side face, the back of a niche, a ledge up a pinnacle), each
  making the climb easier (the table above). Lost with the attempt.

**Always something to do, always something earned.**

- **Everlastings** (the papery Kilimanjaro flower) are spread along the
  walkable ground, never two within 9 tiles (10 on the summit night), so
  they do not bunch up: each is 5 stamina back, they glint so the eye finds the next one, and the
  count shows at the top of the screen.
- **Fall and you drop them.** A slip that counts scatters every everlasting
  you are carrying back onto the ground where you found it: the count goes
  to 0 and you pick them up again on the next go. (Gear goes only with a
  hole or a lost climb.)
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
  (a hop, a grab, a pull-over, sitting out a gust, a dodged stone, a cracked slab, a
  rolling stone, a step onto ice, a find, a cairn). The full-ascent tests fail if a climb
  has more than 5 s of walking with nothing to do, or more than 8 s of
  walking without a real challenge (flowers and cairns do not count as
  challenges). Climbing a face counts as play in itself. On the open
  stretches the gauntlet puts something in the way every second or two;
  the longest gaps left are around camps, cairns and people, where the
  ground is kept clear on purpose.

| Climb | Hazards | Gear |
| --- | --- | --- |
| Lava Tower | a scree bridge of cracked slabs, stonefall down the chimney (a niche halfway up to shelter), the windy lip | goggles and buff on the windy lip, gloves in the chimney niche, poles above the last face |
| Barranco Wall | stonefall down the loose gully, cracked slabs on the exposed ledge where you sit out gusts | gloves in an alcove above ledge 2, goggles and buff in the gully niche below the shoulder, poles on a ledge on the plateau |
| Summit night | ice on two switchbacks, the crevasse, stonefall on two rock steps, cracked slabs on the windy rim, thin air | crampons and a headlamp in pockets off the switchbacks, goggles and buff on a ledge below the rim |

## The crag

`modes/crag/`: Lion Rock. A first-time player is pointed here from the
title ("new? start here") and lands on **First Climb**, a short lesson
that stops the first time each new thing comes up (the rock, a bolt, the
rest on the rope, tiny holds, a big hold, a jump, your first fall), one
or two sentences each. Then six routes, easiest first; each opens when the
one before it is sent. The crag menu always leads with one **Next up**
route, then the **daily route**, the seven routes with their stars and
best results, and the **logbook**. The words on screen are for
non-climbers, with the climbing name after.

### Holds and moves

| Hold | Looks like | How it plays |
| --- | --- | --- |
| Ordinary rock | the pale line | costs a little to move and to hang |
| Crimp (k) | small chalked edges | drains fast, worst if you stop. A grip meter (warm) fades; squeeze GRIP once when it drops below half. A tap during the 0.2 s cooldown waits for it (no tap goes unanswered); squeezes above 70% grip or in a flurry are wasted, and The Pinch's challenge counts them |
| Sloper (z) | round grey domes | friction: moving loses grip by the square of your speed (half speed loses a quarter), holding still lets it settle back. Squeezing does nothing. The meter turns cool blue; out of grip you slide off. Move, pause, move |
| Pocket (u) | dark holes with a lit rim | hang for free; cheap to clip from (1 stamina) |
| Jug (J) | big incut holds | hang to shake out: stamina comes back, with chalk and a sound |
| Blank rock | two rows with nothing | a dyno: JUMP (aim with the stick). A ring closes on the hold; tap GRIP **once** as the hands reach it. Within 0.15 s of contact is a perfect catch (half the jump's stamina back); up to 0.4 s after is a good catch; one tap up to 0.15 s before contact counts. Two or more taps before the hold is near is a snatch: the hands miss |

Every fall names its cause and what to try next ("Pumped on the tiny
holds: keep moving and squeeze when the meter drops below half"; "Slid
off a sloper: move slowly and pause"; "Missed the catch: tap once, just as
your hands reach the hold"; "Snatched too early"; "Hit the ground: clip as
soon as you can low down"). The results card repeats the most common one.
A route tried but not sent shows a chalk line at your high point. Where
the line goes sideways the hint says which way.

### The seven routes

Three things describe a route, apart from each other, as on a real cliff:
**the grade** (how hard the moves are), **the bolting** (how far apart the
bolts are: well bolted up to 3.5 m, sporty up to 6 m, or run-out) and
**the exposure** (how far a fall can go, and whether a fall low down can
reach the ground). Bolting is set per route, not by grade. Each route
tests one skill. Rows are half a metre; maps from
`tools/levels/crag_maps.py`, which also writes `routes/specs.json`;
`modes/crag/route_builder.gd` is the same builder in the game, and a test
checks it makes the seven maps byte for byte.

| Grade | Route | Skill | Height | Bolts (gaps, rows) | Bolting | Exposure | Challenge (third star) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Lesson | First Climb | the basics | 11 m | 3 (7, 7) | well | medium | no falls |
| 4 | Warm-up Wall | clip, rest, repeat | 16.5 m | 6 (5, 5, 5, 5, 5) | well | low | every clip from a good hold (pockets, jug, rock) |
| 5b | Sundown Traverse | slow and steady | 19.5 m | 4 (6, 10, 12) | sporty | high, ground-fall risk | grip on the slopers never below a third |
| 6a | The Pinch | squeeze timing | 21 m | 8 (5, 5, 5, 4, 5, 5, 5) | well | low | clean, no wasted squeezes |
| 6b | Leap of Faith | the timed catch | 25 m | 6 (4, 7, 8, 10, 12) | sporty | high | clean, a perfect catch |
| 6c | Lion's Roof | steep ground | 25 m | 8 (5, 5, 4, 7, 7, 7, 7) | well | medium | no rests on the rope |
| 7a | Thunderhead | all of it, run-out | 29 m | 5 (7, 10, 14, 17) | run-out | high, ground-fall risk | clean, both catches perfect |

- **Read the route first.** The camera runs up the line with the tiny
  holds, big holds, blank rock, every bolt and the long run-outs marked.
  Free: it does not spoil an onsight.
- **Beta.** Tips worked out from the route (where to clip, the slopers,
  the pockets, the catch). Taking it makes a clean first go a flash.
- **Shoes.** Neutral (75% speed, 30% less stamina) or aggressive (130%
  speed, 35% more), picked before each route.
- **Clip.** One tap of CLIP at each bolt. Off a jug it is free, a pocket 1
  stamina, rock 2, crimps or a sloper cost grip and stamina. The tap that
  clips, catches or rests does only that (a CLIP or REST tap on crimps no
  longer also counts as a squeeze, and a catch tap no longer clips).
- **Rest on the rope.** Each clip fills a green rest bar; tap REST to sit
  back and get stamina back from it.
- **How long the arms last.** Every hold has its own cost a second, so
  each one is a clock: on a full bar about 8 s hanging on tiny holds, 25 s
  on a sloper, 50 s on ordinary rock; jugs and pockets stop the clock. The
  stamina line shows it ("Stamina 85% (5 s here)", or "(resting)" on a
  hold that gives it back).
- **Retry and the high point.** After a go the results put **Retry**
  first after a fall short: one tap straight back onto the route in the
  same shoes, no menu, no brief. After the top they put the **next route**
  first and Replay second. Any tap skips the beat before them. The best
  height (half a metre a row) is marked in chalk either side of the line,
  off the holds, and **NEW HIGH POINT** shows only above an earlier one,
  also as you pass it. A short message says when a go ended just short of
  your best or near the anchor, only when that is true. On a replay of
  the lesson, tips seen before become short reminders.
- **Records.** Records and leaderboards, from the crag and expedition
  menus: per route best time, fastest clean ascent, high point, styles,
  first ascent on this device; the daily day's goes ranked; expeditions
  by score with completion meaning the summit and the way down, split by
  route; the World Passport. Friends and Global say they are not
  connected: the online service is designed and has a tested reference
  server (docs/records-backend.md) but is not deployed. Nothing is called
  verified on the device.
- **The grade curve.** Each route has a `pump` (how much every move costs)
  set so the grades ask steadily more: a careful player's lowest point
  goes 79, 71, 69, 57, 50, 45, 31% from the lesson to Thunderhead, and a
  casual player (squeezes late, rests only when half empty) sends every
  route but gets down to the last 5-8% on the two hardest
  (`test_the_grades_climb_in_steady_steps`).
- **Lead falls.** Twice the height above the last clipped bolt plus slack;
  low down, or far above a low bolt, you hit the ground (25 stamina).
- **Style**, honestly: onsight (first go, no falls, no beta), flash (first
  go, no falls, with beta), redpoint (clean, after earlier goes, including
  goes that lowered off), or "top, with falls". A go counts at tie-in.

### Logbook, stars and achievements

`modes/crag/logbook.gd`, shown on the logbook screen. Per route: goes,
falls, sends, best style, best time (and "new best, N s faster"), high
point, the route's challenge. **Stars**: one for the send, two for a
clean send (redpoint or better), three with the route's challenge.
**Achievements** ask for skill shown on a go, never a count of goes (a
hundred sends of the lesson earn only "First send"): onsight, redpoint, a
perfect catch, each skill challenge, Thunderhead without a fall, a clean
sweep, three stars everywhere, a daily send and a daily onsight. Saved in
`user://climb_up_crag.json`; bad or older data loads safely.

### The daily route

`modes/crag/daily.gd`. One route per UTC day, the same for every player on
the same date and `Daily.VERSION`, opened once First Climb is sent:

- **Deterministic.** Seed = FNV-1a of `climbup-daily-v<VERSION>-<date>-<n>`;
  numbers from mulberry32, written out so they never change with the
  engine (tests check both against an independent implementation and
  mulberry32's published output). The route is built by the same
  `RouteBuilder` as the fixed routes, with a name, a grade by weekday
  (easier early in the week) and a featured skill. Bolting is chosen
  apart from the grade.
- **Fair.** `Daily.validate()` refuses a route unless the line is
  continuous, dynos are two-row blanks with holds straight above, every
  bolt is in reach, no more than six rows of hard holds go without a rest,
  and a stamina budget (which charges sideways bands by their holds) never
  runs dry. A day whose first roll fails tries the next sub-seed,
  deterministically. A year of days validates (about two rolls a day); the
  scripted climber leads two weeks of them to the anchor.
- **Logged offline.** Per day: goes, sends, falls, best style, best time;
  and a streak of days in a row with a send (`user://climb_up_daily.json`,
  the last 60 days). No account, no network.
- **Clock honesty.** If the device's date is earlier than a day it has
  already shown, the route can still be climbed but the go is practice and
  is not logged.
- **Sharing.** "Share today's result" copies a text result (works
  anywhere) and saves a picture card with the route's shape drawn hold by
  hold (downloaded on the web; saved to app storage on Android, where a
  native share sheet would need a plugin).
- **Leaderboards later.** `Daily.payload()` is what a server would need to
  check a result: date, version, seed, the map's hash and the go, nothing
  about the player. There is no server: nothing here is global, and no
  ranking is claimed.

## The Barranco Wall

Barranco Camp (talk to Lena and Jun, read the signs) → the approach under
the buttress → a scramble band → the first face → a traverse over a void →
the rest ledge → a steeper face → the exposed ledge (REST in the gusts) →
Marco, stuck: help him, leave him for Lena, or step back → the loose gully
(rest in the niche halfway) → the shoulder and the view → the crouch ledge
in the wind → the upper face → the plateau → Karanga.

Slips send you back to the last cairn; three end the attempt. Turning back
is always in the pause menu. Quitting mid-climb resumes at the last cairn.

## The way down

`levels/kilimanjaro/descent/`. Turn around on the summit and the descent
is played: Stella Point at sunrise, the rim in the wind, long scree, one
rock step climbed down (stand at the edge and push DOWN), an icy bench, a
rest halfway, Barafu. Quieter than the climbs up, with room between the
beats. Jun sits on the rim, spent: short-rope him down beside you (it
costs stamina, he catches your next slip, his breath runs low if you rush)
or leave him with Lena. How it went lands once (`Expedition.finish_descent`):
the card's own move down as before, then the result on stats and score.
Bringing Jun down is teamwork and judgment; leaving him costs the team; a
clean descent is good risk management; a ruinous one can still lose the
expedition after the summit, and a summit without a safe return scores at
most 36. It lives on the trek, outside the Coordinator, so the Expo engine
parity holds, and it adds no extra roll of the mountain's dice: the
scripted parties end exactly as they did before it.

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

119 tests (a script error during a test fails it, not just a failed
check). New this sprint: `test_crag_moves` (the route builder matches the
tools byte for byte; slopers want a steady pace; pockets are free; a dyno
wants one timed tap, perfect, good or a reach just before; mashing a dyno
misses; each route tests its own skill; a traverse says which way),
`test_logbook` (styles named honestly, stars, each challenge asks for its
skill, achievements cannot be ground out, saves survive bad data, the high
point to beat, the next route is always clear), `test_daily` (the numbers
match an independent implementation, one route per day for everyone, a
year of routes validates, two weeks led to the top, results, streaks and
sharing, a clock turned back does not count, the level offers a share),
`test_descent` (the way down's effect, turning around opens it and it
lands once, a ruinous descent can lose the expedition, the level played
start to finish helping Jun), and in `test_platform` the settings page,
playing with the sound off, touch controls for either hand and any size
inside the safe area, and analytics that stay local and private.

The rest: the engine replaying seven expeditions recorded from the
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

## Settings, sound and analytics

- **Settings** (`core/settings/settings_menu.gd`, the same page in every
  pause menu): music and effects volumes apart (each down to off),
  vibration, touch controls on or off, control size (85% to 130%), a
  left-handed layout (buttons left, stick right), graphics quality,
  reduced motion (no shake, no clip pop, no glow pulse), the usage log,
  FPS. Everything stays inside the display's safe area (notches, rounded
  corners). The game plays the same with all sound off.
- **Analytics** (`core/analytics/analytics.gd`, see `docs/analytics.md`):
  local only. Whitelisted events (launch, mode chosen, tutorial started
  and finished, route started, failed, completed and replayed, daily
  started, completed and shared, expedition started, abandoned and
  completed, the descent, achievements, settings, session length) written
  to `user://climb_up_events.jsonl` on the device. A random session id,
  no device or player ids, no network code, no third-party SDK. A
  provider can be added later behind a consent setting (`add_sink`).

## Placeholders and gaps

- **Audio** is synthesized placeholder (see `assets/audio/README.md`),
  including two quiet music loops (crag, camp). Real recordings and a
  composed score are wanted; the hooks (`Audio.play_music`, the hold
  sounds, separate music and effects volumes) are in place.
- **Animation** reuses the side-view sheets; missing frames for a real
  mantle, scramble, traverse, crouch-walk, and a two-person help-up
  (`help` is one pose). Wanted: hand-drawn sheets with those clips.
- **Tiles and props** are generated, not hand-finished.
- **Weather** has wind only; the `Weather` states (fog, rain, snow) are
  designed in the architecture doc, not built.
- **Export**: web and Android (debug) builds exist. They were checked in
  desktop Chromium and in Chromium emulating a phone (touch stick,
  landscape, menu → camp → cards → the Lava Tower), **not on a real
  phone**: thumb feel, haptics and frame rate are unmeasured. The APK is debug-signed, not for
  the Play Store, and sits just under 30 MiB. An iOS export preset exists
  (`export_presets.cfg`: bundle id, iOS 14+, iPhone and iPad) but no iOS
  build has been made or tested: that needs a Mac, Xcode, the iOS export
  template and an Apple team id.
- **Foot placement** is not modelled: on a touchscreen a second set of
  limb controls was judged too fiddly for now. Body position shows only in
  the hold types (slopers want stillness, crimps want movement).
- **Only Kilimanjaro.** Everest and the other mountains in the Expo app
  are not ported.
