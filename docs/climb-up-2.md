# CLIMB UP 2.0: the redesign in the game

The Magic Patterns redesign (branch `feature/magic-patterns-redesign`) is a
React/Vite prototype: screens, flows, tokens and copy. This page records how
it is built natively in the Godot game, what was adapted, and what is still
open.

## Where things are

- **Reference:** `design/magic-patterns/` holds the prototype exactly as
  uploaded (84 files, plus its own `README.md` and `package.json`). The
  upload had overwritten the root `README.md` and `package.json`. The root
  `package.json` belongs to the frozen Expo app and drives the engine parity
  export (`tools/godot/export_content.ts`), so both root files were put back.
  The prototype is not built or shipped. It is a spec to read.
- **Production:** everything playable is in `godot/`, built on the current
  game branch (alpine pitches, per-route maps, the quarter bar on the fastest
  way, rain). The Build Codes in the request were written against
  `main@29e7e09`. They are adapted to this branch's APIs rather than copied in.

## Decisions

1. **One game, not two.** The redesign wraps the game that exists: the hub,
   profile, equipment, camp world, crag select and knowledge checks are new
   screens around the same climbing, scoring, styles, expedition engine and
   route maps. Nothing protected changes (AGENTS.md "Game rules are
   protected").
2. **Flags for anything that changes how a climb plays.** `FeatureFlags`
   (`godot/core/flags/feature_flags.gd`). The new screens are on. Mechanics
   that would change a score or a style (crag clip v2) default off, so
   records stay comparable and the server's checks stay true.
3. **No new bitmaps unless space is freed.** The APK has about 8 KB of room
   under the 31,457,280-byte cap. New UI, the hub landscape, the climber
   portrait and the camp world are drawn in code (`_draw`, gradients,
   polygons). Prototype image URLs (CDN-hosted generated plates) are not
   used: they are not ours to ship and they would break offline play.
4. **Real data only on boards.** The records sheet shows the device's own
   runs and, when the records service is reachable, the server's boards.
   When there is no data, it says so. Nothing is simulated.
5. **Equipment is earned, never bought.** There is no payment integration,
   so there are no real-money purchases. Gear and cosmetics unlock from play
   (sends, stars, summits, finds, knowledge checks).
6. **Knowledge checks are a game, labelled as one.** Every knot, belay,
   anchor and route-reading card carries the line "A game, not a lesson:
   learn climbing from a qualified instructor." The answers follow standard
   practice, and simplifications are named as simplifications.

## API differences from the Build Codes

| Build Code assumes | This branch has |
| --- | --- |
| `leaderPoints` on a run | `points`, `summit`, `artifacts` (`Records.data["expedition"]`) |
| `Party.expedition_hour` is an int | float |
| `CampWidgets.STAT` in `core/ui` | `modes/expedition/camp/camp_widgets.gd` |
| `Artifacts.kept_total` | `Artifacts.kept_on(session, climb)` |
| `barranco.txt` map | per-route maps from `tools/levels/route_levels.py` |
| summit mate from the prototype | Jun (per-route people in `places.gd`) |
| title as the main scene | the hub (`modes/hub/hub.tscn`), and the old title stays reachable |

## Protected and untouched

The expedition engine (`modes/expedition/engine/`), `kilimanjaro.json`, the
178-step parity test, crag scoring and styles, the route maps and their
hashes, achievements, the logbook and the daily route. Tests guard these:
`test_engine_parity`, `test_routes`, `test_logbook`, `test_daily`, and the
new `test_v2_*` tests, which check that the new screens write nothing to the
engine's session.

## Status

See "CLIMB UP 2.0" in `docs/development-roadmap.md` for what each milestone
delivered and what is still open.
