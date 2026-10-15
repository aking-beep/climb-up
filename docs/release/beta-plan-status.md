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

Tests on the final commit: 191 Godot tests passed, 0 failed (online tests
against a live server); 46 server tests OK. GitHub CI and the Android
workflow run on every push.
