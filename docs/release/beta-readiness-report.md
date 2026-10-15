# CLIMB UP: Android closed beta readiness report

| | |
| --- | --- |
| Build audited | `0.9.0-beta.1` (version code 9), `com.climbup.game` |
| Date | 2026-10-15 |
| Branch | `ccr-b5506e55-rahee5` → `main` |
| Environment | A cloud container with Godot 4.7.2, Docker and Python 3.13. No Android device, no emulator, and no access to `dl.google.com` |

**Decision: NO-GO.** The beta can't be distributed through Google Play
yet. Three critical blockers remain:

1. There is no Play upload bundle (AAB).
2. No physical device has been tested.
3. No records service is deployed.

The code, configuration, tests and documents for all three are in place.
What remains needs the publisher's infrastructure, credentials and
devices. The conditions for GO are at the end.

Classifications:
- **PASS:** shown by a build or a test that was actually run here.
- **FAIL:** run, and it doesn't work.
- **BLOCKED:** can't be run here, for the reason given.
- **NOT TESTED:** could be run, but needs something this session lacks
  (a phone, a person).

## A. Android release

| # | Item | Status | Evidence |
| --- | --- | --- | --- |
| A1 | Export presets audited | PASS | `godot/export_presets.cfg`: arm64, Gradle off for the APK and on for the AAB preset, release keystore from the environment only. `show_as_launcher_app=false` is correct: that flag makes the app a *home-screen replacement*. The launcher entry comes from the exported `GodotAppLauncher` alias with `MAIN`/`LAUNCHER`, confirmed in the built manifest |
| A2 | Package identity | PASS | APK manifest: `com.climbup.game` |
| A3 | Launcher icons (adaptive: foreground, background, monochrome, 192 legacy) | PASS (build) / NOT TESTED (device) | In the APK at `res/mipmap-anydpi-v26/icon.xml`. Checked under simulated circle and squircle masks. Not seen on a real launcher |
| A4 | Versioning | PASS | Manifest: `versionName 0.9.0-beta.1`, `versionCode 9`, min/target SDK 24/36. `project.godot` `config/version` matches |
| A5 | **Release AAB** | **BLOCKED** | `tools/godot/export.sh android-aab` was run. It installed the Gradle build template, Gradle 8.11.1 downloaded, then the build failed: `could not resolve plugin artifact 'com.android.application...:8.6.1'`. The Android Gradle plugin is only on Google's Maven (`dl.google.com`), which this environment's network refuses (403). Needs a build machine or runner that can reach `dl.google.com` and `maven.google.com` |
| A6 | Release-signed APK | PASS | `build/godot-android/climb-up-release.apk`, 29,501,881 bytes. `apksigner verify`: v2 and v3 verified (v1 isn't needed at min SDK 24). `debuggable` absent, `allowBackup=false`. Signed with a **temporary** key; see A7 |
| A7 | Secure signing and upload documented | PASS | `docs/release/android-signing.md`: Play App Signing, upload key made offline, env-only passwords, backups, CI secrets. `.gitignore` blocks `*.jks`, `*.keystore`, `keystore.properties`, `*.aab`, `godot/android/`. No key is in the repository |
| A8 | Landscape orientation | PASS (manifest) / NOT TESTED (device) | `screenOrientation=11` (userLandscape: either landscape, never portrait). An earlier setting gave 13 (fullUser, which allows portrait) and was fixed |
| A9 | Lifecycle (pause, focus loss, back button, resume) | PASS (simulated) / NOT TESTED (device) | `test_platform`: backgrounding mid-climb pauses the crag and saves the expedition; Back works on every menu. Records also sync on `NOTIFICATION_APPLICATION_RESUMED`. Not run on a phone |
| A10 | APK size cap (≤ 31,457,280 bytes) | PASS | Release 29,501,881. Debug 31,312,792 (148 KB under the cap) |
| A11 | Permissions are the minimum | PASS | `INTERNET` and `ACCESS_NETWORK_STATE` (online records), `VIBRATE` (haptics, a setting). `INTERNET` was missing before this sprint: online records could never have worked on Android |

## B. Online records

| # | Item | Status | Evidence |
| --- | --- | --- | --- |
| B1 | Deployable production config: HTTPS, persistent DB, backups, health checks, logging | PASS (local) | `server/deploy/`. `docker compose up` was run here with `RECORDS_DOMAIN=localhost`. Results: Caddy served HTTPS (with an HSTS header); `/healthz`, `/v1/firsts` and `/privacy` answered; the container reported `healthy`; the backup job wrote `records-<stamp>.sqlite`; data survived `docker restart` |
| B1b | **Production deployment** | **BLOCKED** | No host, domain or credentials were provided. `climb_up/records/endpoint` is empty in this build, so it shows "not connected" |
| B2 | Godot registration and authentication | PASS | Account screen: age first, consent, optional name. Plus recovery code copy and restore, sign out, delete. `test_online` against a live server |
| B3 | Global and Friends views active | PASS | They read the server's boards: crag time and clean, daily, expedition, first verified ascents, report button. `test_online` checks the Friends and Expedition tabs |
| B4 | First ascents, Daily Crag, Expedition scores across separate accounts | PASS (local server) | `test_online`: three accounts (Ann 30, Bea 30, Cyd 16) climb for real (bot) and sync. Checks: Ann holds the first verified ascent on a fresh server; Bea's later send is not first; both are on today's Daily board; Ann's run is on the Expedition board; 16-year-old Cyd is not on Global; friends boards are correct both ways. Run 3 times in a row (pass each time) plus in the full suites |
| B5 | Local records kept offline | PASS | `test_online` › offline: the server is unreachable, the go waits in the queue, the personal record is kept, the board says why. `test_records` › flaky network, retries, duplicates |
| B6 | Recovery and moderation safeguards | PASS | Recovery: `GET /v1/me` restores on another device (tested). Moderation: `admin.py` reports, hide-name, ban/unban, resolve; extra blocked words from a file; 10 reports a day; 30 accounts an hour per address; banned players refused and hidden (`test_operations`, 13 tests) |
| B7 | Against a deployed production service | NOT TESTED | Nothing is deployed (B1b) |

## C. Quality

| # | Item | Status | Evidence |
| --- | --- | --- | --- |
| C1 | All tests rerun | PASS | Server: **43 tests OK**. Game: **184 passed, 0 failed**, with `RECORDS_SERVER` set, so the live-server tests ran instead of being skipped |
| C2 | CI | PASS | `.github/workflows/ci.yml`: server unit tests, the Docker image and its health check, and the Godot 4.7.2 headless suite against a fresh server. **GitHub Actions run 38779986667 on PR #14 passed** (both the "Records service" and "Game tests (Godot headless)" jobs, commit 8b69cf7). The same steps on a fresh local clone also passed and caught a test-order leak in the new campaign test, now fixed |
| C3 | Every Crag route | PASS | `test_crag` › every route is led to the anchor: the lesson and all six graded routes (4 to 7a) sent by the bot with every bolt clipped. `test_records` and `test_online` send today's Daily route |
| C4 | Full Kilimanjaro campaign | PASS (automated) / NOT TESTED (human) | New `test_campaign`: seeds 7, 8 and 9 go from the gate to the walk-out through the `Expedition` autoload. Every camp card is played; Lava Tower, Barranco Wall, summit night and the descent each open with their brief, and their outcomes land; the save reloads identically at every step; the run is recorded as a completion. Each climb is also played for real by bots (`test_climbs`, `test_barranco`, `test_descent`). No human has played it end to end on a phone |
| C5 | Saves, retries, leaderboard sync, network failures | PASS | `test_flow` (resume from a cairn, identical replay), `test_rules` (bad save files refused), `test_arcade` (20 retries leave nothing behind, retry to playable in 110 ms), `test_records` and `test_online` (sync, duplicates, 401/5xx/no network) |
| C6 | Physical-device matrix | **NOT TESTED** | `docs/release/device-test-matrix.md`: 6 device classes, every row NOT TESTED. There is no device or emulator here |
| C7 | Frame rate, touch latency, thermal, crashes | **NOT TESTED** (device) | Desktop CPU per frame, headless on a Xeon 2.1 GHz: Lava Tower 1.09 ms average (p95 1.37); Barranco 1.04 (1.69); summit 0.64 (1.22); crag 0.50 to 0.70. That suggests plenty of headroom, but it is not device evidence. GPU, thermal and touch latency need phones |

## D. Store compliance

| # | Item | Status | Evidence |
| --- | --- | --- | --- |
| D1 | Privacy policy | PASS (text) / BLOCKED (publisher details) | `server/deploy/site/privacy.html`, served at `/privacy` (checked). It matches what the code collects. The publisher name, contact and effective date are placeholders |
| D2 | Data safety | PASS | `docs/release/data-safety.md`, answers traced to the code. No ads, no sharing, encrypted in transit, in-app deletion |
| D3 | Age protections, consent, deletion, name moderation | PASS | `docs/release/age-and-moderation.md`. No accounts under 13 (tested). Consent is required before anything is sent (tested). Deletion is in the app (tested). Moderation tools (tested). Open items are listed there |
| D4 | Closed-test assets | PASS (desktop-rendered) | `store/icon-512.png`, `store/feature-graphic-1024x500.png`, 5 screenshots at 1440 × 810 rendered by the game. They were not captured on a phone |
| D5 | Support info | **BLOCKED** | Needs the publisher's support email and name (placeholders in `play-listing.md` and the policy). I didn't use a personal email without asking |
| D6 | Release notes | PASS | `docs/release/play-listing.md` |

## Test commands and results (this run)

```sh
python3 -m unittest discover -s server/records_service/tests -t .
# Ran 43 tests ... OK

python3 -m server.records_service.service --db /tmp/e2e.sqlite --port 18181 &
RECORDS_SERVER=http://127.0.0.1:18181 godot --headless --fixed-fps 60 --path godot res://tests/runner.tscn
# 184 passed, 0 failed

# CI dry run on a fresh clone (no .godot cache): import, then the same two commands
# 43 OK; 184 passed, 0 failed

RECORDS_SERVER=... godot ... res://tests/runner.tscn -- only=test_online   # 3 runs in a row
# 3 passed, 0 failed (each time)

godot --headless --fixed-fps 60 --path godot res://tests/perf.tscn
cd server/deploy && RECORDS_DOMAIN=localhost docker compose up -d --build   # then curl /healthz, /privacy, /v1/firsts over https
GODOT=... tools/godot/export.sh all            # web + debug APK: exit 0
GODOT=... tools/godot/export.sh android-release  # exit 0
GODOT=... tools/godot/export.sh android-aab      # exit 1: Android Gradle plugin unreachable (A5)
apksigner verify --print-certs build/godot-android/climb-up-release.apk  # Verifies (v2, v3)
```

## Artifacts

| Artifact | Location |
| --- | --- |
| Release-signed APK (temporary key; side-load testing only) | `build/godot-android/climb-up-release.apk` (29,501,881 bytes), sent in the session |
| Debug APK | `build/godot-android/climb-up.apk` (31,312,792 bytes) |
| Web build | https://claude.ai/artifact/B7Ychh6pzaydeNPpztuKSv (version 38) |
| AAB | none (A5) |
| Records service image | `docker build -f server/Dockerfile .` |
| Store assets | `store/` |

Build outputs under `build/` aren't committed.

## Deployment requirements

See `docs/release/README.md`. In short:
1. a Docker host, a domain, and off-host backups;
2. the publisher's details;
3. an upload key made offline;
4. a build machine that can reach Google's Maven;
5. the endpoint set in `project.godot`;
6. device testing;
7. a moderator.

## Remaining defects

**Critical (block the beta):**
1. **No AAB** (A5). Play accepts only AABs. It needs network access to
   Google's Maven, or a build machine that has it.
2. **No device evidence** (A3, A8, A9, C6, C7). Nothing has run on a
   phone: install, orientation, touch, frame rate, thermal, lifecycle,
   crashes.
3. **No deployed records service** (B1b, B7). As built, the beta has no
   working competitive leaderboards: they say "not connected" until a
   service is deployed and its address is set in the build.

**Major:**

4. **Publisher identity and support contact missing** (D1, D5). Play
   requires a support email and a privacy policy URL with the right
   publisher.
5. **The release APK is signed with a temporary key** that this session
   discards (A6). Use it only for side-loading. Builds signed with the
   real upload key can't update it.
6. **The recovery code is the account token, with no rotation.** A leaked
   code means delete and re-create the account. The UI says so. Add
   rotation before a wider release.
7. **Store screenshots are desktop renders.** Acceptable for a closed
   test, but replace them with phone captures before an open test.

**Minor:**

8. Name filtering matches inside words, so "Essex" is refused. The player
   picks another name.
9. In an altitude emergency on the summit, choosing "Everyone goes down,
   now" skips the played descent level. That is consistent with the
   emergency fiction, and the campaign test covers the normal path.
10. A GDScript runtime error inside a test stops that test's coroutine,
    and the runner waits. CI's 30-minute timeout catches it.
11. The account throttle (30 an hour per address) lives in memory and
    resets on restart.

## Conditions for GO

1. Build the AAB on a machine with Google Maven access, signed with the
   publisher's upload key. Run `bundletool validate`.
2. Deploy `server/deploy` on a real domain and fill in the privacy page.
   Set `records/endpoint` and `records/privacy_url`, then rebuild.
3. Run `device-test-matrix.md` rows 1–4 with no critical findings. Then
   run `test_online`'s scenario by hand on two phones.
4. Complete Play Console:
   - listing, support email and Data safety;
   - content rating and target audience (13+).
5. Keep CI green. It passed on PR #14.
