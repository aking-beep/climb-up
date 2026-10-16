# CLIMB UP: instructions for coding agents

CLIMB UP is a **Godot 4.7 game** (GDScript) for Android phones, played
sideways. There's also a web build. A small Python records service backs
the online leaderboards. **All new game work goes in `godot/`.**

The Expo / React Native app at the repository root (`src/`, `app.json`,
`package.json`) is the **original prototype and is frozen**. Don't add
features to it, upgrade its packages, or follow Expo conventions for the
game. Change it only when a task names it. The one exception is the
expedition engine parity test: the Godot engine is checked against the
TypeScript engine (`tools/godot/export_content.ts`).

## Where things are

| Path | What |
| --- | --- |
| `godot/` | The game. `project.godot`, `export_presets.cfg` (Web, Android APK, iOS, Android AAB) |
| `godot/core/` | Autoloads and shared systems: input, player and climbing, audio, haptics, save, settings, records and online, analytics, UI |
| `godot/modes/` | Screens and modes: `title/`, `crag/`, `expedition/` (engine, camp, levels), `records/` |
| `godot/tests/` | Headless test suite (`runner.tscn`, `test_*.gd`, bots in `crag_bot.gd` and `climb_bot.gd`) |
| `server/records_service/` | Records service: Python standard library only (sqlite3 and wsgiref). `validate.py` holds the anti-cheat checks, `admin.py` is moderation, `backup.py` handles backup, restore and drill |
| `server/deploy/` | Fly.io, Render, Docker Compose and Caddy configs, plus the privacy page |
| `tools/` | Asset generators (`art/`, `audio/`, `levels/`), `godot/export.sh`, `android/emulator_smoke.sh`, `release/make_upload_key.sh`, `playtest/retention.py` |
| `docs/` | Design, testing, playtest plan, roadmap (`development-roadmap.md`), release kit (`docs/release/`) |
| `.github/workflows/` | `ci.yml` (server, container, Godot suite), `android.yml` (AAB, emulators, Play upload), `deploy-records.yml`, `backup-records.yml` |

## Commands

```bash
# Godot 4.7.2 (stable). Set GODOT to the binary.
$GODOT --headless --path godot --import                                     # once, to build the import cache
$GODOT --headless --fixed-fps 60 --path godot res://tests/runner.tscn          # the whole suite
$GODOT --headless --fixed-fps 60 --path godot res://tests/runner.tscn -- only=test_crag

# The online tests need a running records service:
python3 -m server.records_service.service --db /tmp/r.sqlite --port 8765 &
RECORDS_SERVER=http://127.0.0.1:8765 $GODOT --headless --fixed-fps 60 --path godot res://tests/runner.tscn

python3 -m unittest discover -s server/records_service/tests -t .           # server tests
python3 -m unittest discover -s tools/playtest                              # playtest measures tool

GODOT=$GODOT sh tools/godot/export.sh web|android|android-release|android-aab|all
```

Before calling a task done, run the Godot suite (with `RECORDS_SERVER` if
you touched records, online or the service) and the server tests. They
must all pass.

## Rules

- **Godot APIs change between versions.** Check the 4.7 docs
  (https://docs.godotengine.org/en/4.7/) rather than memory, especially
  for Godot 3-era names (`KinematicBody2D`, `yield`, `export var`, and so
  on). Use typed GDScript (`var x := ...`, `-> void`) like the code around
  it.
- **Tests:**
  - Every behaviour change gets a test in `godot/tests/`. Server
    changes get one in `server/records_service/tests/`.
  - Never weaken, skip or delete a test to get green. If a test is
    wrong, fix it and say why.
- **Game rules are protected.** Don't change these without being asked:
  - scoring;
  - styles (onsight, flash, redpoint);
  - the expedition engine;
  - route maps (the server checks each map's hash);
  - achievements;
  - the logbook and the daily route.
  If you change a route map or the score, regenerate the server's
  `server/records_service/data/routes.json` and the test fixtures, and
  keep `validate.py` matching the game.
- **Mobile first:**
  - Landscape, touch only, thumbs at the screen edges.
  - Keep the frame budget for a mid-range Android phone.
  - The APK must stay at or under **31,457,280 bytes**.
  - The shader cache stays off (`project.godot`). Emulators filled it to
    gigabytes.
- **`godot/android/` is generated** (the Gradle build template, ignored by
  git). Configure Android in `export_presets.cfg`, never by editing that
  folder.
- **Never commit secrets:**
  - Keystores (`*.jks`, `*.keystore`), `keystore.properties`, passwords,
    tokens, `*.aab` and database backups never go in git.
  - Signing keys and the Fly token live in GitHub Actions secrets
    (`docs/release/android-signing.md`).
- **Privacy:**
  - Analytics stay on the device unless the player opts in
    (`docs/analytics.md`).
  - Under-13 accounts get no public name and no global boards.
  - Don't add third-party SDKs (ads, analytics, crash reporting) without
    an explicit decision recorded in `docs/`.
- **Don't claim device testing you didn't do.** Emulators and headless
  runs are not physical-phone tests.
- **Docs:** when a feature, a command or the go-live state changes,
  update `docs/development-roadmap.md` and the relevant page in `docs/`.
