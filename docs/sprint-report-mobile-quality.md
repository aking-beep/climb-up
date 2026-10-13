# Sprint report: mobile quality and gameplay refinement

Branch `ccr-b5506e55-rahee5`, from main at `9cf7aff`. Both modes stay in
the one Godot project (`godot/`), and the Expo prototype is untouched; its
typecheck still passes. No mountains or routes were added.

This report separates three kinds of evidence:

- **Headless:** the Godot test suite, run with `--headless --fixed-fps 60`.
- **Emulated:** the web build in headless Chromium with SwiftShader software
  rendering, mobile viewport and touch emulation, driven by Playwright.
- **Physical device:** nothing in this report was run on a real phone or
  tablet. Everything that needs one is listed under "Needs a real device".

## Summary

| Area | Result |
| --- | --- |
| Tests | 74 → 88 headless tests, all passing, no script errors. 14 new tests cover changed mechanics. |
| Crag tapping | Grip taps for a sensible player went from about 4 a second on every stretch of tiny holds (old meter, computed) to 0 to 6 per route (measured). |
| Crag realism | Lead falls are twice the height above the last bolt plus slack. Ground falls exist. Grade, bolting and exposure are separate. |
| Progression bugs | Three fixed: opening a brief counted as a go, which could cost an onsight; a save with wrong types crashed the crag loader; the same happened to the settings loader. |
| Expedition bugs | A regroup released the hour's stones at once: 60 in the air against 2 now. A rolling stone could start on top of a respawned climber. Brief and notes contradicted each other. |
| Phone | Pause and save when the app loses focus or goes to the background. Android back button. Vibration is its own setting, and the Android build now has the VIBRATE permission it lacked. Menus and panels scroll on short screens. |
| Needs a device | Real frame rate, heat, touch latency, vibration, notch and safe areas, real app backgrounding on iOS and Android. |

## 1. Mobile quality audit

### Verified in emulation (Chromium, software rendering, 844×390 at 2×, plus the viewports in the audit)

**Baseline audit of main, before any change.** It was run by a separate agent; screenshots are in the session scratchpad.

- Boot: the title is on screen about 4 s after load. There were no console errors and no script errors.
- Portrait shows the "Turn your phone sideways" overlay.
- The stick, ACT (CLIMB and CLIP) and the pause button all work by touch.
- Crag progress and a mid-expedition save both survive a reload (IndexedDB).
- **Found (high):** the Crag route list was cut off at the top and bottom at 844×390 at 2×, on an iPhone SE (667×375) and on a 1024×768 tablet.
- **Found (medium):** losing focus did not pause the game. There was no handler for it.
- **Found (medium):**
  - Tap targets: panel buttons were about 27 CSS px and the pause button about 39 CSS px, against a 44 CSS px guideline.
  - The smallest text was 7 logical px.
- **Found (low):**
  - Hints drawn over the sky had no backing.
  - Phones were shown keyboard help.
  - "Continue · day 0" was shown while the camp said day 1.
- Frame rate in software rendering was 2 to 3 fps. That is not representative of phones and was not used for any decision.

**After the fixes (same harness, new build):**

- The route list fits and scrolls.
- The brief, lesson and pause panels fit and open at the top. A short panel after a tall one is short again.
- Hiding the page mid-climb (visibilitychange and blur) brought up the pause menu.
- No console errors.

### Verified headless (tests)

- Going to the background mid-climb pauses the Crag. The clock, the climber and stamina all freeze, Resume resumes, and a second interruption does not stack a second menu (`test_platform`).
- Going to the background mid-expedition-climb pauses and saves. A fresh load reads the climb as it was.
- The back button opens pause on a climb. Menus handle back, and the app no longer quits outright on back.
- Vibration has its own setting and ignores reduced motion. A settings file with wrong types loads as defaults.
- Panels fit a 270-px-tall screen, scroll, open at the top, and shrink back for a short panel.

**CPU cost per frame** (headless on a 4-core x86 server, so the rendering cost is not included). Measured with `tests/perf.tscn`; the climber walks and climbs with every hazard live.

| Climb | Average | 95th percentile | Max | Nodes |
| --- | --- | --- | --- | --- |
| Lava Tower | 0.68 ms | 1.18 ms | 48 ms* | 180 |
| Barranco Wall | 0.76 ms | 2.10 ms | 3.4 ms | 264 |
| Summit night | 0.69 ms | 1.33 ms | 6.7 ms | 344 |
| Crag warm-up | 0.66 ms | 1.07 ms | 23 ms* | 106 |
| Crag Thunderhead | 0.96 ms | 1.47 ms | 7.2 ms | 181 |

\* A one-off at the first frames after the scene loads, not a recurring hitch.

The simulation is far inside a 16.7 ms frame even if a phone CPU is several
times slower. Whether rendering keeps 60 fps can only be measured on a phone.

### Fixed

- **Interruptions:** `Settings` turns app pause, app focus-out and window focus-out into an `interrupted` signal. Both climb levels pause on it, and the expedition also saves the climb's state.
- **Android back button:** it no longer quits the app. It opens pause on a climb and goes back a screen on the menus (the title screen quits).
- **Vibration:**
  - It has its own setting (pause → Settings → Vibration), separate from reduced motion.
  - The Android preset now asks for `VIBRATE`. The built APK's manifest was checked and includes it.
  - Before this, haptics could not have worked on Android: the preset never asked for the permission.
  - New buzzes on the Crag: clip, stuck dyno, ground fall, and reaching the top.
- **Readability:**
  - Menu cards and story panels scroll when they are taller than the screen.
  - Panel buttons are 24 logical px (about 36 CSS px at 2×) with more space between them.
  - The pause button is 32 px.
  - Kickers are 8 px.
  - Hints have a dark backing.
  - The pause menus are short (Resume, route or turn back, Settings, quit), with the toggles on a separate Settings page.
- **Copy:** phones get thumb controls on the expedition menu instead of key help. The continue label counts days from 1.

## 2. Crag gameplay refinement

| Change | What it was | What it is now |
| --- | --- | --- |
| Grip on tiny holds | The meter drained at the route's full rate even while moving; each tap +25%. Holding steady on the 7a took about 4 taps a second (computed). | Drains at 0.35× of the route rate while you move and 1.3× when you stop; a squeeze is +45%, with a 0.2 s cooldown. A sensible player uses 0 to 6 squeezes per route (measured below). Mashing gives exactly the grip of squeezing at the cap rate, for 6× the taps (tested). |
| Crux interactions | Kept | One tap to clip, and three fast taps to stick a dyno. Both now have a chalk puff, their own sounds, and a buzz. |
| Hold-to-hold movement | Continuous slide, silent | Every reach (9 px) is a move with a hold sound (sharper on tiny holds). Moves are counted and shown on the results card. |
| Lead falls | You landed level with the last bolt, whatever the height | Twice your height above the last clipped bolt plus slack, with a rope whoosh and "A 4.5 m fall". A fall low down can hit the ground: a thump, 25 stamina, and back to the foot of the cliff with bolts still clipped. |
| Grade, bolting and exposure | Bolt spacing grew with the grade | Three separate axes, all shown in the brief and the route list. Bolting and exposure are computed from each map. See below. |
| Route reading | None | "Look at the route first": the camera runs up the line with tiny holds, big holds, jumps, bolts and run-outs labelled. It is free, it does not spoil an onsight, and it is also in the pause menu. |
| Beta | None | Tips generated from the route. Taking beta makes a clean first go a flash. |
| Traverses and dynos | Unchanged mechanics | Covered by the same grip and catch changes. Both routes with dynos are still sent in tests. |

**Taps per route,** measured with the test bot playing as a sensible player (squeezing only when grip drops below half):

| Route | Grip | Clip | Catch | Rest | Moves | Time | Stamina left |
| --- | --- | --- | --- | --- | --- | --- | --- |
| First Climb | 0 | 4 | 3 | 4 | 34 | 17 s | 83% |
| Warm-up (4) | 0 | 6 | 0 | 5 | 50 | 23 s | 86% |
| Sundown (5b) | 0 | 4 | 0 | 6 | 83 | 40 s | 86% |
| The Pinch (6a) | 1 | 8 | 0 | 6 | 73 | 32 s | 63% |
| Leap of Faith (6b) | 3 | 5 | 3 | 6 | 85 | 41 s | 58% |
| Lion's Roof (6c) | 6 | 7 | 3 | 8 | 98 | 48 s | 60% |
| Thunderhead (7a) | 6 | 5 | 6 | 5 | 107 | 52 s | 26% |

**Grade, bolting and exposure, apart.** Rows are half a metre.

| Route | Grade | Bolting | Exposure |
| --- | --- | --- | --- |
| Warm-up | 4 | well bolted (6 bolts, ≤ 2.5 m) | low |
| Sundown | 5b | sporty (4 bolts, ≤ 6 m, high first bolt) | high, ground-fall risk |
| The Pinch | 6a | well bolted (8 bolts, ≤ 2.5 m) | low |
| Leap of Faith | 6b | sporty (≤ 6 m) | high |
| Lion's Roof | 6c | well bolted (8 bolts, ≤ 3.5 m) | medium |
| Thunderhead | 7a | run-out (5 bolts, ≤ 8.5 m) | high, ground-fall risk |

This replaces last round's "bolts spread with the grade" on purpose: you
asked for the grade to be separated from bolt spacing.

## 3. Expedition gameplay refinement

A separate read-only audit ran the climb tests with the existing pacing debug output. It measured:

| Climb | Bot time | Moments when the player acts | Longest quiet stretch |
| --- | --- | --- | --- |
| Lava Tower | 61 s | 46 | 4.5 s |
| Barranco | 156 s | 75 | 3.2 s |
| Summit night | 329 s | 207 | 4.0 s |

All are inside the pacing tests' limits. The strategy → play → consequence
loop was already clear at camp. The fixes go after what broke it or contradicted it:

- **Stone storm after a regroup (bug).**
  - The regroup's hour, or a resumed save, made every missed stone fall at once: 60 in the air on Barranco in the test, and the audit saw over 900 rolling on the summit night.
  - `Hazards.skip_to()` moves each chute and roller on to its next drop instead.
  - The test fails without the fix.
- **Respawn into a stone.** The Lava Tower's first cairn sits beside a stone spawner. No rolling stone now starts within 3 tiles of the climber. The test fails without the fix.
- **The brief states the consequence:** "After: each slip costs the party N health at camp (up to M); topping out under 25% stamina costs 4 energy."
- **Missing teammates stay missing.**
  - The brief no longer sends you looking for a teammate who has gone down.
  - People at the start no longer talk about them.
  - The "Lena brings Marco up later" note is dropped when Lena has gone.
- **Teammates are present:**
  - A sick teammate's state shows in the help panel.
  - A teammate you helped speaks at each cairn on the Barranco Wall and the summit night.
- **Small fixes:**
  - The last slip says the climb is over, where it used to say "back to the last cairn".
  - The regroup label matches the hour the trek charges.
  - The results card stays up 45 s instead of 15.
- **Engine parity:** the ExpeditionEngine, Party and Coordinator rules are unchanged, and the parity tests pass.

## 4. Visual and audio quality

- Screens change with a short fade (instant with reduced motion).
- Chalk puffs on a clip, a squeeze and a stuck dyno. A dust burst and a camera kick on a ground fall.
- New synthesized sounds:
  - `clip`: a gate snap.
  - `chalk`
  - `whip`: rope running.
  - `thud`

  They were made after the existing sounds, which regenerate byte-identical.
- The route preview has labelled stretches and bolts, kept on opposite sides of the line so they never overlap.
- **Deferred:** new character animation frames and new terrain art. See below.

## 5. Progression and correctness

| Item | Before | After |
| --- | --- | --- |
| When a go counts | When the brief opened. "Back to the climbs" from the brief still counted, so it could cost an onsight. | When you tie in. Tested. |
| Styles | Onsight, redpoint, "sent with falls" | Onsight (first go, no falls, no beta) and flash (first go, no falls, with beta), plus redpoint and "top, with falls (not a clean ascent)". Ranked onsight > flash > redpoint > with falls. |
| Lowering off | Nothing kept | Your high point (most bolts clipped) is kept and shown in the route list and the brief. |
| Unlocks | Any top-out opens the next route | Unchanged on purpose: a top-out with falls still opens the next route, to keep it approachable. |
| Save integrity | `int("x")` or `"yes" == true` crashed the loader | Crag and settings loaders type-check every field and fall back to defaults. Tested with a deliberately bad file. |
| Scoring | Best style, best falls, best time | Same, plus the high point. Best time is still kept for any top-out (see deferred). |

## 6. Regression testing

- `godot --headless --fixed-fps 60 --path godot res://tests/runner.tscn`: **88 passed, 0 failed, no SCRIPT ERROR lines.** The runner can report a pass despite a script error, so every run's log was checked for those lines; one real crash was found that way.
- New and changed tests:
  - `test_crag`, 16 tests: lead-fall height, ground fall, grip squeezes against mashing, grade/bolting/exposure, preview and beta, tie-in counting, flash, high point, bad save.
  - `test_platform`, 6 tests: interruptions for both modes, back button, vibration setting, bad settings file, panels on a short screen.
  - `test_pacing`, 5 tests: stone storm, spawn safety, brief costs, gone teammate, last slip.
- Two of the new tests were checked by breaking the fix and watching them fail.
- `npx tsc --noEmit` for the Expo prototype passes.
- Builds: the web export runs in emulated Chromium with no console errors. The Android APK is signed, `apksigner verify` passes, and its manifest has VIBRATE.
- Docs updated: `godot/README.md` (crag, phone, tests) and `docs/playtest-checklist.md` (crag table and an interruptions section).

## Needs a real device

Use `docs/playtest-checklist.md`. These cannot be settled in emulation:

1. **Frame rate and heat:** sustained frame rate, frame pacing and thermal throttling on a mid-range Android phone and an iPhone. The emulated renderer is software only.
2. **Backgrounding on real phones:** the home button, the lock screen, the notification shade, a call, and swiping the app away. Emulation showed the pause on visibility/blur; iOS Safari and Android Chrome have to confirm it.
3. **Vibration:** it should be felt on Android, both in the APK and in Chrome. iOS Safari has no vibration API, so silence there is expected.
4. **Touch:** latency, and holding the stick and ACT or JUMP at the same time.
5. **Screen edges:** notches, cutouts and the Android gesture bar around the HUD and the pause button. The page does not use `viewport-fit=cover`.
6. **Text size on DPR-3 phones:** the smallest text is about 10.7 CSS px.
7. **Audio:** the new sounds on phone speakers, and audio resuming after an interruption.
8. **iOS storage:** whether IndexedDB saves get evicted after a week unused.

## Deferred (not started, or kept out of scope on purpose)

- **New character animation frames:** a reach, a clip pose, a fall pose. The climber still uses the existing climb/hang/fall cycles; the new feel comes from sound, chalk and camera.
- **New terrain art:** for example roof textures and crag-specific rock variety. Needs an art pass, not a code change.
- **Hold-to-hold movement:** the climbing is still continuous with move feedback. A true move-by-move (discrete) system would change every route's balance and the bot.
- **Traverse and roof cost:** a steeper cost on roofs (feet cut loose) is a balance change to make after phone playtests.
- **Best time for clean sends only:** a scoring rule to decide.
- **The `pressed_now()` edge:** the first script to check a button press consumes it. That caused the preview-skip bug, fixed by reading it in one place. Other code could still trip on this. A per-frame input snapshot would remove the whole class of bug.
- **Expedition audit leftovers:**
  - Shorter walk-offs after the last real move: about 20 to 35 tiles on the Lava Tower and Barranco.
  - Dead fields: `Companion.trust`/`condition` and `Trek.climb_factor` sick/stamina.
  - A Lava Tower teammate line.
- **Low readability items:**
  - The HUD box has empty space under the stats.
  - The climber starts under the stick's ring.
  - The ACT button is faint while it has no action.
- **Not done here:** merging to main; this is on the branch until you say so.
