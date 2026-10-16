# Beta implementation plan: status

The status of each item in the P0–P4 plan for the 30–50 person external
playtest. Rules, scoring, lessons, the daily route, achievements, the
logbook and the records screens are unchanged throughout.

| Item | Status | Where | Validation still needed |
| --- | --- | --- | --- |
| **P0.1** Phone checklist, fix what it breaks | **Needs you.** Done on emulators only: Android 10 and 14 in CI, covering install, landscape lock, home and resume, 1,500 random touches, a second cold start, storage under 50 MB. It found and fixed the 5.8 GB shader-cache bug | `tools/android/emulator_smoke.sh`, `.github/workflows/android.yml` | One mid-range Android phone through `docs/playtest-checklist.md`: FPS, thumbs, haptics, home, lock, call, back, notch, battery |
| **P0.2** The two builds the playtest names | Done | `build/godot-android/climb-up.apk` (debug, 31.3 MB), web build (claude.ai artifact, version 40) | The APK on the P0.1 phone; one iPhone Safari pass of the title and First Climb |
| **P0.3** Point testers at the Godot playtest | Done | `docs/testing.md` | none |
| **P0.4** Invite says records are local | Done | `docs/playtest-invite.md`, linked from `playtest-plan.md`; the build sets no records address | Fill in the two install links |
| **P1.1** Results card leads with the number | Done | `CragLevel.result_lead()`; tests in `test_records`, `test_arcade` | Day-0 sessions: do people retry? |
| **P2.1** Squeeze: buzz and audible chalk; cooldown tick | Done | `CragLevel._grip()` | Loudness and buzz on the P0.1 phone |
| **P2.2** Each reach heard | Done: hold trims −20 to −8 dB; footsteps unchanged | `Audio.TRIM`; `test_audio` | Music on, on the phone |
| **P2.3** One clip click | Done: one gate click, 28 ms; second chime removed | `CragLevel._clip()` | Phone |
| **P2.4** A hit on the fall | Done: a 3-frame hit-stop, then a short hard kick; reduced motion never shakes | `HitStop`, `ExpeditionCamera.kick(strength, fade)` | Phone |
| **P2.5** A perfect catch apart from a plain one | Done: hit-stop and 45 ms for perfect; plain unchanged | `CragLevel._stick()` | Phone |
| **P2.6** The body crosses the edge | Done: mantle kick and top-out sting; Uhuru kick and sting before its sentence | `ClimbLevel` | One look on the phone |
| **P3.1** Stamina under 25% | Done: the bar pulses; breath comes faster and carries over the music | `Hud`, `Climber._breathing()` | Phone, for breath level |
| **P3.2** A click for the verb that fired | Done: pitched per verb; clip keeps its gate; never with a panel open | `CragLevel.TAP_PITCH` | Phone |
| **P3.3** Achievement sting; streak beside the time | Done | `CragLevel.finish()` | none |
| **P3.4** Tell the player when a save does not land | Done: a notice over any screen, at most once a minute; the old save stays whole | `SaveGame._failed()`, `Settings.notice()` | Only if P0.1 loses a save |
| **P4** Post-beta | Not scheduled. The account screen, sync, service deploy, AAB build and Play upload were built earlier. The playtest build turns none of them on (no records address) | | |

Tests after the review fixes (16 October 2026): 191 Godot tests passed,
0 failed (online tests against a live server); 64 server tests and 3
playtest-tool tests OK. GitHub CI and the Android workflow run on every
push.

## Review findings (16 October 2026)

| Finding | Status | Where | Still needed |
| --- | --- | --- | --- |
| **P0** The Android bundle uses a throwaway signature | **Needs you.** The key must be made on your own computer, never in a cloud session. The script, secrets and workflow are ready | `tools/release/make_upload_key.sh`, `android-signing.md` | Run the script; check `SIGNED_WITH.txt` says "upload key" |
| **P0** No physical-device playtests | **Needs you.** The APK is built and emulator-tested | `docs/playtest-checklist.md`, `device-test-matrix.md`, `tools/android/emulator_smoke.sh` | One mid-range phone through the checklist; results in the matrix |
| **P0** Retention unmeasured | **Tooling done; the beta needs you.** `retention.py` computes D1, D7 and every log-based measure in the plan, with tests | `tools/playtest/retention.py`, `docs/playtest-plan.md` | Run the 30–50 person beta and the script |
| **P1** AGENTS.md pointed agents at Expo | Done. Godot is the target; the Expo prototype is frozen; `CLAUDE.md` points at the same file | `AGENTS.md`, `CLAUDE.md` | none |
| **P1** The roadmap described the Expo state | Done. Rewritten for the Godot game: state, Gate 1 (beta), Gate 2 (public launch), later | `docs/development-roadmap.md` | none |
| **P1** Limited anti-cheat | Stronger checks built. The server refuses a replayed log, checks a steady clock and height sampling, and holds outliers for a moderator (`admin.py review`, `approve`, `refuse`) | `validate.py`, `service.py`, `admin.py`, `records-backend.md` §3 | Before a competitive public launch: Play Integrity, then server-side replay (roadmap, Gate 2) |
| **P1** Off-host backup not verified | Done. Verify, restore and drill commands; restore-on-boot for Fly and Render; a nightly off-host encrypted backup with the drill; the drill runs in the shipped container in CI | `backup.py`, `restore_on_boot.sh`, `.github/workflows/backup-records.yml`, `server/deploy/README.md` | Add `BACKUP_PASSPHRASE` after deploying; one manual restore rehearsal before launch |
| **P2** No native iOS pipeline | Planned. The iOS preset is aligned with Android (`com.climbup.game`, 0.9.0) | `docs/release/ios-plan.md` | After Android validation: Apple account, Mac or macOS CI, signing, TestFlight |
| **P2** Monetization and donations undefined | Defined as a decision gated on retention: what is never sold, four options, and a donation flow that fits the store rules | `docs/monetization-and-donations.md` | Decide after the beta's numbers |
