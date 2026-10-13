# Sprint report: the 9.5 sprint (Crag first)

Branch `ccr-b5506e55-rahee5`. This sprint worked in phases and put a
complete Crag vertical slice first, then the daily route, the platform,
and the Expedition's descent. Quality is an aspiration here, not a
measured score: nothing in this report comes from players or physical
phones. What was tested, and how, is listed below.

## Baseline (start of sprint)

- 90 tests passing (`godot --headless --fixed-fps 60 --path godot
  res://tests/runner.tscn`), the last graphics pass committed.
- Risks found in the audit: the dyno was a three-tap mash; one kind of
  small hold (crimps) carried all the difficulty; a CLIP or REST tap on
  crimps also counted as a squeeze; a dyno's catch tap could also clip a
  bolt; the test runner reported a test as passing even when its script
  errored part way; no progression beyond best style per route; no
  reason to come back daily; the Expedition's descent was cards only; the
  APK was within 20 KB of the 30 MiB file limit used to hand it over.

## What changed

### Crag moves (commit 851a722)

- **Holds that play differently.** Slopers (move slowly, pause to let
  the grip settle; squeezing does nothing; out of grip you slide off),
  pockets (free to hang on, cheap to clip from), alongside crimps (keep
  moving, squeeze once when the meter drops) and jugs (shake out). Each
  has its own art and sound.
- **The dyno is timing, not mashing.** A ring closes on the target hold;
  one tap as the hands arrive sticks it. Perfect (within 0.15 s) gives
  back half the jump's stamina; a reach up to 0.15 s early counts;
  snatching at the air misses.
- **Falls teach.** Every fall names its cause (pump, crimps, sloper, a
  late or snatched catch, the ground) and the fix, and the results card
  repeats the most common one.
- **Seven routes, seven skills.** Clip-rest-repeat, slow and steady,
  squeeze timing, the timed catch, steep ground, all of it run-out.
  Grade, bolting and exposure stay separate.
- **Bugs fixed:** the catch tap clipping a bolt; CLIP/REST taps counting
  as squeezes; a squeeze in the cooldown silently doing nothing (it now
  waits for the cooldown).

### Progression (851a722, 85f1083)

- **Logbook:** goes, falls, sends, best style and time, high point,
  stars (send, clean send, the route's skill challenge), achievements
  that reward skill and cannot be ground out. A logbook screen; a chalk
  line at your high point on a route not yet sent.
- **Honest styles:** onsight, flash, redpoint, "top, with falls"; a go
  that lowered off still counts, so a later clean send is a redpoint.

### The daily route (85f1083)

- One route per UTC day for everyone, from the date and a version
  number, with its own portable hash and random numbers; validated for
  fairness (and re-rolled deterministically if not); logged offline with
  a streak; a clock turned back makes a go practice; shared as text and
  as a picture card. A payload shape is ready for a future server, but no
  backend exists and no rankings are claimed.

### Onboarding and the menus (85f1083, 851a722)

- The title points a new player at the crag ("new? start here") and says
  in one line each what the two modes are.
- The crag menu always leads with one "Next up" route; the results card
  offers the next route.
- Lesson cards cut to one or two sentences each, plus a card for the
  first fall.

### Platform (c2b1b23)

- One settings page everywhere: music and effects volumes apart,
  vibration, touch controls on/off, control size 85–130%, a left-handed
  layout, graphics, reduced motion, the usage log, FPS.
- Touch controls and HUD inside the display's safe area.
- Quiet music hooks (crag, camp; none on the expedition climbs), new
  hold and top-out sounds; the game plays the same with sound off.
- Local-only analytics with a fixed event list (`docs/analytics.md`) and
  a "Copy my usage log" button for playtesters.
- An iOS export preset (not built: see below).

### Expedition (35e2b2d)

- **The way down, played.** Turning around on the summit opens a descent
  level: sunrise on the rim, wind, long scree, a rock step climbed down,
  ice, a rest halfway. Jun is spent on the rim: short-rope him down or
  leave him with Lena. The result lands on health, the team and the score;
  a ruinous descent can still lose the expedition after the summit.
- It adds no extra roll of the engine's dice: the scripted test parties
  end exactly as before it (all routes and play styles), and the Expo
  engine parity holds.
- The expedition menu says plainly that altitude, illness and medicine
  are game rules, not advice.

### Builds and polish (08a0f59)

- A traverse hint that says which way; music and ambience imported at
  11 kHz and the camp plates at WebP 0.75 to keep the APK under 30 MiB.

## Files

**New:** `godot/modes/crag/{route_builder,daily,logbook,logbook_screen,share_card}.gd`,
`logbook_screen.tscn`, `routes/specs.json`;
`godot/core/analytics/analytics.gd`; `godot/core/settings/settings_menu.gd`;
`godot/core/ui/star_row.gd`;
`godot/modes/expedition/levels/kilimanjaro/descent/{descent.gd,descent.tscn,descent.txt}`;
`godot/assets/crag/{sloper,pocket}-hd.png`; seven new sounds and two music
loops in `godot/assets/audio/placeholder/`;
`godot/tests/{crag_bot,test_crag_moves,test_logbook,test_daily,test_descent}.gd`;
`docs/{analytics,playtest-plan,art-brief,sprint-report-9-5}.md`.

**Changed (main ones):** `godot/modes/crag/{crag,crag_level,crag_menu,tap_meter}.gd`,
the seven route maps, `godot/core/world/terrain.gd`,
`godot/core/player/climber.gd`, `godot/core/climbing/stamina_model.gd`,
`godot/core/audio/audio.gd`, `godot/core/settings/settings.gd`,
`godot/core/input/{touch_controls,touch_stick}.gd`, `godot/core/ui/{hud,panel}.gd`,
`godot/modes/title/title.gd`, `godot/modes/expedition/{expedition,menu}.gd`,
`godot/modes/expedition/{camp/camp.gd,engine/trek.gd,levels/climb_level.gd}`,
`godot/export_presets.cfg`, `godot/project.godot`, `godot/tests/{runner,test_crag,test_platform,test_trek}.gd`,
`tools/levels/{crag_maps,kili_maps}.py`, `tools/art/crag_hd.py`,
`tools/audio/placeholders.py`, `godot/README.md`.

## Tests

`godot --headless --fixed-fps 60 --path godot res://tests/runner.tscn`
(Godot 4.7.2): **119 passed, 0 failed** (exit code 0), up from 90. By
suite: barranco 7, body 9, climbs 14, crag 16, crag_moves 7, daily 7,
descent 4, engine_parity 3, flow 8, logbook 7, pacing 5, platform 12,
rules 12, trek 8. No test was removed or weakened. Three were rewritten
for changed rules, each to check the new behaviour: the dyno catch (one
tap, with perfect and good timing), the lesson count (the fall lesson
only appears after a fall), and the title layout (Crag first for a new
player). The runner now also fails a test when its script errors.

Measured by the scripted climber (not players): every route sent, all
bolts clipped; the lesson in 16 s of game time; 14 consecutive daily
routes sent; the descent in 65 s of game time with Jun; a year of daily
routes validated, about two rolls a day on average.

## Builds

- Web: `build/godot-web/` (plain) and `build/godot-web-artifact/` (packed),
  published to the project's artifact page.
- Android: `build/godot-android/climb-up.apk`, debug-signed, arm64,
  31.4 MB, `apksigner verify` passes.
- iOS: a preset only. Export fails here with "No export template found",
  as expected without Apple tooling. **Not built, not tested.**

## Tested only in automation or emulation

- Everything above ran headless or in a desktop browser emulating a
  phone (Chromium via Playwright, landscape, touch). Layout of the touch
  controls, safe areas and left-handed mode was checked in a 480 × 270
  sub-viewport and with a simulated cutout.
- Sound was checked only as "the game asks for it and plays the same with
  it off"; nobody has listened on a phone speaker.

## Needs physical devices

Touch feel of the timed catch and the sloper pace; real safe areas
(notches, punch-holes, gesture bars); frame rate and heat on mid-range
and low-end Android; haptics strength; audio levels; interruptions
(calls, alarms, lock); clipboard and file saving for the share card on
Android; the web build on iPhone Safari; the whole of iOS.

## Known gaps and limits

- Art and audio are generated placeholders (see `docs/art-brief.md`):
  no dedicated animation frames for grips, clipping, the dyno or the
  short-rope.
- No foot placement: judged too fiddly for touch for now.
- Sharing on Android copies text and saves a picture into the app's
  storage; there is no native share sheet (that needs a plugin).
- Daily results are local; no server, accounts or rankings.
- The APK is 17 KB under the 30 MiB file limit used to hand it over;
  the next asset will need a split build (AAB) or trimmed content.
- The scripted climber never falls on the daily routes; real players will.
  The daily routes' difficulty spread needs playtest data.
- Expedition pacing was changed only by adding the descent; the climbs
  up were not re-paced this sprint.

## Next three highest-value tasks

1. **Run the playtest** in `docs/playtest-plan.md` with 30+ testers on
   real phones: tutorial completion, replay, D1/D7, and touch feel of
   the catch and the slopers. Tune from that before adding content.
2. **Commission character animation** for grips, clipping, the dyno and
   the short-rope (`docs/art-brief.md`), the biggest gap in moment-to-
   moment satisfaction.
3. **Ship a store-ready Android build** (release keystore, AAB, Play
   Console internal testing), which also removes the size squeeze, then a
   real iOS build on Apple hardware.
