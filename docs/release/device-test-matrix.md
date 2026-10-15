# Device test matrix: closed beta 0.9.0-beta.1

**Status:**
- **Emulators: PASS on every push**, in the *Android* workflow on
  Android 10 (API 29) and Android 14 (API 34).
- **Physical phones: NOT TESTED.**

Every phone row below stays NOT TESTED until a person runs it on that
phone. Play's pre-launch report for the closed-test build adds real
devices automatically. `tools/android/emulator_smoke.sh` runs the same
automated checks on a phone plugged in over USB.

## Emulators (automated, every push)

| Image | Install | Launch, running 25 s later | Landscape in portrait | After turning | Home and resume | 1,500 random touches | Second cold start | Game crashes, ANRs, script errors | Cold start | Memory (PSS) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Android 14 (API 34), x86_64, Pixel 6 screen | PASS | PASS | PASS (ROTATION_90) | PASS (ROTATION_270) | PASS (same process) | PASS | PASS | none | 2.0 s | 161 MB |
| Android 10 (API 29), x86_64, Pixel 6 screen | PASS | PASS | PASS (ROTATION_90) | PASS (ROTATION_270) | PASS (same process) | PASS | PASS | none | slower (shared CI runner) | 164 MB |

Emulators render with a software GPU, so they say nothing about real
frame rate, heat or touch feel.

## Phones (minimum set for the closed beta)

| # | Device class | Example | Android | GPU | Install | Launch | Crag route | Expedition climb | Online sign-up + sync | Background/resume | 30 min thermal | FPS | Touch | Result |
| - | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Low-end, min SDK | Android 7–8, 2–3 GB RAM (e.g. Moto E5 / Galaxy J-series) | 7.0–8.1 | Adreno 3xx / Mali-T | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | **NOT TESTED** |
| 2 | Budget current | Galaxy A1x/A2x, Redmi | 12–14 | Mali-G57 / Adreno 6xx | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | **NOT TESTED** |
| 3 | Mid-range | Pixel 6a / 7a | 14–15 | Mali-G78 / G710 | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | **NOT TESTED** |
| 4 | Flagship, newest Android | Pixel 9 / Galaxy S24+ | 15–16 | latest | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | **NOT TESTED** |
| 5 | Tall / notched screen | 20:9 or 21:9 with a cutout | any | any | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | **NOT TESTED** |
| 6 | Tablet | 10" Android tablet | any | any | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | **NOT TESTED** |

For each phone, also record:
- the model and Android version;
- the build: version code 9, signed with the upload key;
- the tester and the date.

## What to check on each phone

1. **Install and launch.**
   - The adaptive icon shows correctly on the launcher.
   - The game opens in landscape and turns with the phone (either way
     up), never portrait.
   - Cold start takes under 5 s.
2. **Crag.**
   - Play the tutorial route, then Lion's Roof (dynos).
   - Retry 10 times in a row: no slowdown.
   - Check the touch controls reach every hold and the clip button; no
     missed taps.
3. **Expedition.**
   - Start an expedition, play the Lava Tower, then quit from the pause
     menu and reopen: it resumes at the last cairn.
4. **Lifecycle.**
   - Press Home mid-climb, then return: the game is paused, nothing is
     lost.
   - Lock the screen, unlock: the same.
   - Take a phone call: the same.
   - Use the Back button on every screen.
5. **Online** (with a deployed service):
   - Sign up (age, consent). Climb with flight mode on: the go waits.
     Turn flight mode off and reopen the app: it is sent.
   - Check Global and Friends.
   - Copy the recovery code. Restore on a second phone.
   - Delete the account.
6. **Thermal and battery.**
   - Play 30 minutes of summit night at full brightness.
   - Note the battery drop and whether the phone throttles: does FPS
     fall?
7. **Frame rate.**
   - Enable "Show refresh rate" or use `adb shell dumpsys gfxinfo
     com.climbup.game`.
   - Target: a steady 60 fps on rows 2–4, and at least 30 on row 1.
8. **Crashes.**
   - Play Console → Android vitals, after the testers have played.
   - Locally: `adb logcat -s godot AndroidRuntime`.

## What was measured without a device

| Check | How | Result |
| --- | --- | --- |
| APK installs: manifest, permissions, orientation, signing | androguard and apksigner on `build/godot-android/climb-up-release.apk` | PASS (see the readiness report) |
| Simulation and scene CPU per frame (headless, Intel Xeon 2.1 GHz, 4 cores) | `godot --headless --fixed-fps 60 res://tests/perf.tscn` | Lava Tower 1.09 ms avg (p95 1.37), Barranco 1.04 (1.69), summit night 0.64 (1.22), crag warm-up 0.50 (0.92), Thunderhead 0.70 (1.23). One 199 ms first-frame spike on the Lava Tower is loading. Rendering not measured |
| Retry to playable | `test_arcade` | 110 ms (headless desktop) |
| Touch controls fit the hand and the screen | `test_platform` › touch controls | PASS (layout only, no real touches) |
| Backgrounding pauses and saves | `test_platform` (notifications simulated) | PASS (simulated, not on a device) |
| Panels fit a short screen | `test_platform`, `test_camp` (480×270 and 360×270) | PASS |

A phone's CPU is about 2–4 times slower per core than this desktop.
Even so, the simulation would fit well inside a 16.7 ms frame. The real
limits on a phone are GPU fill and thermal throttling. Only a device can
show those.
