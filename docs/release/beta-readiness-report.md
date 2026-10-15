# CLIMB UP: Android closed beta readiness report

| | |
| --- | --- |
| Build audited | `0.9.0-beta.1` (version code 9), `com.climbup.game` |
| Date | 2026-10-15 |
| Branch | `ccr-b5506e55-rahee5` → `main` |
| Environment | A cloud container with Godot 4.7.2, Docker and Python 3.13 (no Android device, no `dl.google.com`), plus GitHub Actions for the AAB (Gradle) and the Android emulators |

**Decision: NO-GO today, GO as soon as four account steps are done.**
Every engineering blocker found in the audit is closed:
- The Play bundle (AAB) builds and validates in CI.
- The game runs cleanly on Android 10 and 14 emulators: install, landscape
  lock, background and resume, random touches, a second cold start.
- The records service deploys to Fly.io in one click.
- Recovery codes can be rotated.
- The publisher details are filled in.

What is left needs your accounts. Each step takes minutes
(`docs/release/README.md`, "Go-live checklist"):

1. **Deploy the records service.** Fly.io account, `FLY_API_TOKEN`
   secret, run *Deploy records service*, set `RECORDS_ENDPOINT`.
2. **Make the upload key** on your computer
   (`tools/release/make_upload_key.sh`) and set the three
   `ANDROID_UPLOAD_*` secrets.
3. **Create the app in Google Play Console** ($25 registration). Fill in
   the listing and forms from `docs/release/`. Upload the signed AAB
   from the *Android* workflow to the closed-testing track.
4. **Check on real phones.** Read Play's pre-launch report for the
   closed-test build. Play it on at least two phones of your own
   (`device-test-matrix.md`).

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
| A3 | Launcher icons (adaptive: foreground, background, monochrome, 192 legacy) | PASS (build) / NOT TESTED (real launcher) | In the APK and AAB (`res/mipmap-anydpi-v26/icon.xml`, all densities). Checked under simulated circle and squircle masks. Not seen on a phone's launcher |
| A4 | Versioning | PASS | Manifest: `versionName 0.9.0-beta.1`, `versionCode 9`, min/target SDK 24/36. `project.godot` `config/version` matches |
| A5 | **Release AAB** | **PASS** (built, validated) / signing with your upload key pending | Built with Gradle by `.github/workflows/android.yml` on GitHub's runners. This container can't reach Google's Maven; the earlier run here failed for that reason. `bundletool validate` passed. Manifest: `com.climbup.game`, versionCode 9, 0.9.0-beta.1, 3 permissions, `screenOrientation` 11. `jarsigner` verifies it. Play download size for an arm64 phone: **29,288,285 bytes**. [Run](https://github.com/aking-beep/climb-up/actions/runs/38795755668). Until the `ANDROID_UPLOAD_*` secrets exist it is signed with a throwaway key and marked NOT FOR PLAY |
| A6 | Release-signed APK | PASS | `build/godot-android/climb-up-release.apk`, 29,501,881 bytes. `apksigner verify`: v2 and v3 verified (v1 isn't needed at min SDK 24). `debuggable` absent, `allowBackup=false`. Signed with a **temporary** key; see A7 |
| A7 | Secure signing and upload documented | PASS | `docs/release/android-signing.md`: Play App Signing, upload key made offline, env-only passwords, backups, CI secrets. `.gitignore` blocks `*.jks`, `*.keystore`, `keystore.properties`, `*.aab`, `godot/android/`. No key is in the repository |
| A8 | Landscape orientation | PASS (manifest, emulator) / NOT TESTED (physical) | `screenOrientation=11` (userLandscape). On emulators running Android 10 and 14 with the device held in portrait: ROTATION_90. After turning the device: ROTATION_270. Never portrait |
| A9 | Lifecycle (pause, focus loss, back button, resume) | PASS (tests, emulator) / NOT TESTED (physical) | `test_platform`: backgrounding mid-climb pauses the crag and saves the expedition. Emulators (API 29, 34): Home then back resumes **the same process**; a second cold start runs |
| A10 | APK size cap (≤ 31,457,280 bytes) | PASS | Release 29,501,881. Debug 31,312,792 (148 KB under the cap) |
| A11 | Permissions are the minimum | PASS | `INTERNET` and `ACCESS_NETWORK_STATE` (online records), `VIBRATE` (haptics, a setting). `INTERNET` was missing before this sprint: online records could never have worked on Android |

## B. Online records

| # | Item | Status | Evidence |
| --- | --- | --- | --- |
| B1 | Deployable production config: HTTPS, persistent DB, backups, health checks, logging | PASS (local) | `server/deploy/`. `docker compose up` was run here with `RECORDS_DOMAIN=localhost`. Results: Caddy served HTTPS (with an HSTS header); `/healthz`, `/v1/firsts` and `/privacy` answered; the container reported `healthy`; the backup job wrote `records-<stamp>.sqlite`; data survived `docker restart` |
| B1b | **Production deployment** | **BLOCKED** (needs your Fly.io account) | Ready to deploy: `.github/workflows/deploy-records.yml` deploys to Fly.io from the Actions tab once the `FLY_API_TOKEN` secret exists. It creates the app (`climbup-records-arc`) and its volume, then checks `/healthz` and `/privacy`. The image was tested here on a root-owned volume, as Fly and Render mount them: it took ownership of the volume, dropped to uid 10001, served HTTPS-ready `/healthz` and `/privacy`, and wrote its first backup. The release build reads the address from the `RECORDS_ENDPOINT` variable |
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
| C6 | Device matrix | PASS (2 emulators) / **NOT TESTED** (physical) | `tools/android/emulator_smoke.sh` in CI on Android 10 (API 29) and Android 14 (API 34) emulators, x86_64, Pixel 6 screen, [run](https://github.com/aking-beep/climb-up/actions/runs/38795755668). Passed: install; launch, still running 25 s later; landscape in portrait and after turning the device; Home and resume; 1,500 random touches with no crash or hang; a second cold start; no game crash, ANR or Godot script error in logcat. No physical phone yet: Play's pre-launch report on the closed track covers real devices |
| C7 | Frame rate, touch latency, thermal, crashes | Crashes: PASS (emulator) / frame rate, touch latency, thermal: **NOT TESTED** (physical) | Emulator: cold start 2.0 s to first frame (API 34); memory 161–164 MB PSS; no crash in 1,500 random touches on either Android version. Desktop CPU per frame: 0.5–1.1 ms. GPU frame rate, thermal and touch latency need real phones |

## D. Store compliance

| # | Item | Status | Evidence |
| --- | --- | --- | --- |
| D1 | Privacy policy | PASS | `server/deploy/site/privacy.html`, served by the service itself at `/privacy` (tested). Publisher ARC Transformation Group, contact aking@arctransformationgroup.com, effective 15 October 2026 |
| D2 | Data safety | PASS | `docs/release/data-safety.md`, answers traced to the code. No ads, no sharing, encrypted in transit, in-app deletion |
| D3 | Age protections, consent, deletion, name moderation | PASS | `docs/release/age-and-moderation.md`. No accounts under 13 (tested). Consent is required before anything is sent (tested). Deletion is in the app (tested). Moderation tools (tested). Open items are listed there |
| D4 | Closed-test assets | PASS (desktop-rendered) | `store/icon-512.png`, `store/feature-graphic-1024x500.png`, 5 screenshots at 1440 × 810 rendered by the game. They were not captured on a phone |
| D5 | Support info | PASS | ARC Transformation Group, aking@arctransformationgroup.com (`play-listing.md`, the privacy policy, the release notes, `store/whatsnew`) |
| D6 | Release notes | PASS | `docs/release/play-listing.md` |

## Test commands and results

On GitHub Actions for commit 5b325ba:
- **CI** (run 38795755706): server tests, the Docker image's health
  check, and the full Godot suite against a fresh server. Success.
- **Android** (run 38795755668): Gradle AAB, bundletool, and the emulator
  smoke tests on API 29 and 34. Success.

Here:

```sh
python3 -m unittest discover -s server/records_service/tests -t .
# Ran 46 tests ... OK   (43 at the first audit; + rotation, privacy page, self-backups)

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
GODOT=... tools/godot/export.sh android-aab      # exit 1 here: Google's Maven unreachable; built in CI instead (A5)
docker run ... -v <root-owned dir>:/data climbup-records   # /healthz, /privacy, sign-up, backup written; runs as uid 10001
apksigner verify --print-certs build/godot-android/climb-up-release.apk  # Verifies (v2, v3)
```

## Artifacts

| Artifact | Location |
| --- | --- |
| Release-signed APK (temporary key; side-load testing only) | `build/godot-android/climb-up-release.apk` (29,501,881 bytes), sent in the session |
| Debug APK | `build/godot-android/climb-up.apk` (31,312,792 bytes) |
| Web build | https://claude.ai/artifact/B7Ychh6pzaydeNPpztuKSv (version 38) |
| AAB (throwaway signature until the upload key secrets exist) | `climb-up-aab` artifact of each *Android* workflow run, e.g. https://github.com/aking-beep/climb-up/actions/runs/38795755668 |
| Emulator screenshots, logcat, summary | `emulator-smoke-api29` and `emulator-smoke-api34` artifacts of the same run |
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

**Critical:** none in the code. The three launch blockers from the first
audit are resolved or reduced to account steps:
- AAB: built in CI.
- Device evidence: emulators pass; physical phones remain.
- Records service: deploy is one click.

**Major (need your action, not code):**
1. **Not yet deployed** (B1b, B7). Until `RECORDS_ENDPOINT` is set, the
   build keeps records on the device and the online boards say "not
   connected".
2. **No upload key yet** (A5). The CI bundle is signed with a throwaway
   key and refuses to upload to Play.
3. **No physical-device run yet** (C6, C7). Emulators can't show:
   - GPU frame rate;
   - heat and battery drain;
   - real touch latency;
   - how the icon looks on a real launcher.

   Play's pre-launch report and your own phones close this.

**Fixed since the first audit:** recovery-code rotation (`POST
/v1/me/rotate`, "Get a new recovery code"); publisher and support
details. Behind a proxy, the account throttle now trusts the address the
proxy added, not one the client sent.

**Minor:**
4. Store screenshots are desktop renders. Fine for a closed test;
   capture phone screenshots before open testing.
5. Name filtering matches inside words, so "Essex" is refused. The player
   picks another name.
6. An altitude emergency on the summit ("Everyone goes down, now") skips
   the played descent level. That is consistent with the fiction.
7. A GDScript runtime error inside a test stops that test's coroutine.
   CI's timeout catches it.
8. The account throttle lives in memory and resets when the service
   restarts.

## Conditions for GO

1. Deploy the records service. *Deploy records service* passes its
   `/healthz` and `/privacy` checks.
2. Set the `ANDROID_UPLOAD_*` secrets and `RECORDS_ENDPOINT`. Run
   *Android*: `SIGNED_WITH.txt` says "upload key", and the emulator jobs
   pass.
3. Play Console: the listing, Data safety, content rating and target
   audience 13+ are complete, and the AAB is on the closed track.
4. The pre-launch report shows no crashes, and two of your own phones
   pass `device-test-matrix.md` rows 1–4. Any gaps there are fixed.
