# CLIMB UP external playtest plan (30–50 testers)

This plan is for the first outside test of the Godot build. None of the
numbers below have been measured yet: they are definitions and targets,
not results. Everything measured so far comes from automated tests and
emulation (see `docs/sprint-report-9-5.md`).

## Goals

1. Can a first-time player get from launch to a finished First Climb,
   understanding clipping, grip, resting and falling, without help?
2. Is the crag fun enough that people replay routes and come back the
   next day for the daily route?
3. Does Expedition read as "how high you climb isn't how you win": do
   players turn around, help teammates, and care about the descent?
4. Does it work on real phones: touch feel, frame rate, battery, heat,
   interruptions, haptics?

## Who

Recruit 40 (to end with at least 30 complete), in four groups of about
ten:

| Group | Who | Why |
| --- | --- | --- |
| A | Experienced climbers (lead climbing, 6a or harder) | Terminology, route logic, whether the moves feel like climbing |
| B | Casual climbers / gym boulderers | The core audience |
| C | Non-climbers who play mobile games weekly | Onboarding, clarity, retention |
| D | Non-climbers who rarely play games | The floor: can anyone get through the first five minutes |

Across the groups: at least 8 Android devices from the last four years
at mid-range prices (e.g. 4 GB RAM), at least 4 older or low-end Android
devices, and as many iPhones as can be tested through the web build (no
native iOS build exists). Note each device's model and OS version.

## Invite

Send [playtest-invite.md](playtest-invite.md). It tells testers that
records are on their phone, that Friends and Global say "not connected",
and how to copy the usage log from Settings.

## Sessions

- **Day 0, moderated (30 min, video call or in person, screen shared or
  recorded with consent).** Install, launch, no instructions. Think
  aloud. Facilitator says nothing during the first five minutes except
  "what are you thinking?". Then 10 minutes free play, then the survey.
- **Days 1–7, unmoderated.** Testers play when they like. No reminders
  except one message on day 3. On day 7 they paste their usage log
  (Settings → "Copy my usage log") into the form and fill in the exit
  survey.

## First-five-minutes script (Day 0)

The facilitator ticks each step with its time from launch:

1. Title read; mode chosen (which, and why, in their words).
2. Crag menu: taps "Start here: First Climb".
3. Walks to the rock and grabs it.
4. Clips the first bolt (sees "Clip in").
5. Rests on the rope.
6. Squeezes GRIP on tiny holds.
7. Attempts the dyno; catches it (or falls; note what they said).
8. Tops out; reads the results card.
9. Says, unprompted or when asked, which route to try next.

Then four questions: What does clipping do? What happens when you fall?
When should you squeeze GRIP? What is the difference between Crag and
Expedition?

## Measurements

All from the pasted usage logs (`docs/analytics.md`), except where marked
survey or observation. `tools/playtest/retention.py` computes every
log-based row below. Save one file per tester in a folder, plus an
optional `testers.csv` (file, UTC offset, group), then run
`python3 tools/playtest/retention.py logs/ --testers testers.csv --json report.json`.
It prints counts beside percentages and doesn't report a group of fewer
than 8. A tester's "day" is their local calendar day of
`t`; day 1 is the day of their first `game_launched`.

| Measure | Definition | Target for this build |
| --- | --- | --- |
| Tutorial completion | testers with `tutorial_completed` ÷ testers with `tutorial_started` | ≥ 85% |
| Time to finish the tutorial | median `t(tutorial_completed) − t(first game_launched)` | ≤ 5 min |
| First-five-minutes success (observation) | steps 1–9 above done without help, ÷ moderated testers | ≥ 70% |
| Concept check (survey) | testers who answer all four questions correctly | ≥ 70% |
| Voluntary route replay | testers with at least one `route_replayed` where `sent_before` is true, ÷ testers who sent any graded route | ≥ 40% |
| Crag completion rate, per route | testers with `route_completed` on the route ÷ testers with `route_started` on it | report per route; expect a falling curve, not a cliff |
| Attempts to send, per route | median number of `route_started` before the first `route_completed` | 1–2 for 4–5b, 2–5 for 6a–7a |
| Daily participation | testers with `daily_started` on at least 3 of days 1–7 ÷ testers who unlocked it | ≥ 30% |
| Day 1 retention | testers with any `game_launched` on day 2 ÷ all testers | report (small-sample benchmark: 35–40%) |
| Day 7 retention | testers with any `game_launched` on day 7 or 8 ÷ all testers | report (benchmark: 10–15%) |
| Session length | median `seconds` of `session_ended` | report |
| Expedition completion | testers with `expedition_completed` ÷ testers with `expedition_started` | report |
| Expedition safe return | `expedition_completed` with `returned` true ÷ all `expedition_completed` | report |
| Retreat rate | expeditions completed without `summit` ÷ all completed | report; some retreats is the design working |
| Descent help rate | `descent_completed` with `assisted` true ÷ all `descent_completed` | report |
| Crash / stuck rate (survey + observation) | testers who hit a crash, a soft-lock or lost progress | 0 |

With 30–50 testers these are directional only: report counts alongside
percentages ("12 of 31"), and do not compare groups of fewer than 8.

## Device checks (each Android tester, Day 0)

- Turn on Settings → Show FPS for one route; note the lowest number seen.
- Background the app mid-climb (home button), come back: paused, nothing
  lost?
- Lock the phone mid-climb, unlock: same.
- A phone call or alarm during play: same.
- Vibration felt on clips, catches and falls? Turned off in Settings,
  gone?
- Left-handed layout and the largest control size: usable?
- Notch or rounded corners: anything hidden?
- After 15 minutes: phone warm? Battery used?

## Exit survey (Day 7)

1. How fun was the crag? (1–7) The expedition? (1–7)
2. Which route did you replay most, and why?
3. Did any fall feel unfair? Which, and what happened?
4. Did you ever tap a lot without it helping? Where?
5. In Expedition, did you turn around or leave a teammate? Why?
6. Would you play tomorrow if you could? (yes / maybe / no) Would you
   pay for more mountains? (open)
7. Climbers only: anything that is wrong about the climbing words or
   rules?
8. Anything that broke, confused you, or felt slow?

## Running it

- Build: the signed debug APK (`build/godot-android/climb-up.apk`) for
  Android testers; the web build for iPhones and desktop.
- Consent: tell testers that the game keeps a usage log on their device,
  that they choose to paste it, and what is in it (link
  `docs/analytics.md`). Delete pasted logs after the analysis.
- Analysis: one spreadsheet row per event, keyed by tester. Compute the
  table above. Pair every number with the observation notes.
- Decision rules: if tutorial completion is under 70%, fix onboarding
  before anything else. If no route is replayed by 40% of testers, the
  crag loop needs work before more content.
