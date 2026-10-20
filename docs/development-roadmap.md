# Development roadmap

The current state of CLIMB UP and what comes next, in order. "Done" means
built and covered by automated tests: the Godot suite headless, the
records-service tests, and the Android emulator smoke test in CI.
**Nothing has been played on a physical phone by the team yet.** That is
the first gate below.

The Godot game in `godot/` is the product. The Expo app at the repository
root is the frozen original prototype (see `AGENTS.md`). The earlier
Expo-era roadmap is in git history (this file before October 2026).

## Where it stands (October 2026)

| Area | State |
| --- | --- |
| **Crag** | Done. Seven routes, from First Climb (the lesson) to the hardest, led from the ground: clip bolts, squeeze small holds, dynos, falls caught by the last clip. Styles (onsight, flash, redpoint), logbook, stars, achievements, a daily route, instant retry, high-point marks, near-miss. |
| **Expedition** | Done. Kilimanjaro on three routes (Lemosho, Machame, Umbwe): camp decisions with hours, costs and risk bands, sickness, medicine, sending people down, seven endings; each route shows its own camps and climbs. Each route climbs its own places (`modes/expedition/places.gd`): the long way the Shira Cathedral, the Karanga Valley and Stella Point; the faster way the Lava Tower, the Barranco Wall and the Southern Icefields; the fastest way the Umbwe Ridge, the Arrow Glacier and the Western Breach; and a way down in each route's weather. Nine places, each with its own map, look (rock palette, sky, skylines, plants, weather), people's words and gear (`tools/levels/route_levels.py`, every one played to the end in the tests). The route sets the stamina bar (full, half, a quarter) and the hurt (half on the long way); every obstacle costs stamina or a slip. Gear and the two artifacts per place lie off the line, on ledges you climb for; finds go in a pack and work only when you use them. Artifacts are lost on a slip and worth +6 leader points each when the team gets home. |
| **Feel** | Done, P1–P3 of the playtest plan: squeeze buzz and chalk, clip click, hit-stop and camera kick on falls, perfect catch, top-out sting, low-stamina pulse and breath, per-verb clicks, a save-failure notice. |
| **Records** | Done. Local records always. An optional online service (anonymous accounts, recovery codes, friends, global, daily and expedition boards, first verified ascents, reports, moderation). Off in the playtest build: no records address is set. |
| **Integrity** | Done for beta (`docs/records-backend.md` §3). The server recomputes styles and scores and checks the event log: speed, bolt order, falls, a steady clock and height sampling. It refuses a log it has already taken, and holds outlier records for a moderator (`admin.py review`). |
| **Operations** | Done. Docker image, Fly.io deploy workflow, the service's own daily backups. A nightly off-host backup with a restore drill (`backup-records.yml`). Restore and drill commands, tested in CI. |
| **Android** | Done. Debug APK and AAB built and checked in GitHub Actions. Smoke-tested on Android 10 and 14 emulators: install, landscape, home and resume, 1,500 random touches, cold start, storage. Signed with a throwaway key until the upload key is added. |
| **Web** | Done. A web build for iPhone testers (Safari, sideways). |
| **iOS (native)** | Not started. There is an export preset and a plan (`docs/release/ios-plan.md`). |
| **Money** | Not started, on purpose. Decided after retention is known (`docs/monetization-and-donations.md`). |

## Gate 1: closed beta (P0, needs the team's accounts and hands)

These can't be done from code. Each one is ready to run.

1. **The permanent Play upload key.**
   1. Run `sh tools/release/make_upload_key.sh "CN=CLIMB UP, O=ARC Labs"`
      on your own computer, not a cloud session. It sets the three
      `ANDROID_UPLOAD_*` secrets.
   2. Back up the `.jks` and its password offline.
   3. Run the Android workflow. `SIGNED_WITH.txt` must say "upload key".
   4. Steps: `docs/release/android-signing.md`.
2. **Physical-phone tests.**
   - Install the APK on at least one mid-range Android phone. Go through
     `docs/playtest-checklist.md` and `docs/release/device-test-matrix.md`:
     touch, frame rate, interruptions (home, lock, call), save and resume,
     the back button, the notch, battery and heat.
   - `tools/android/emulator_smoke.sh` runs the CI checks on a phone over
     USB.
   - Record the results in the matrix. Anything that breaks is fixed
     before invites go out.
3. **The 30–50 person beta** (`docs/playtest-plan.md`).
   1. Send `docs/playtest-invite.md` with the two install links.
   2. Collect the pasted usage logs at the end.
   3. Run `python3 tools/playtest/retention.py logs/ --testers testers.csv`.
      It prints D1 and D7 retention, tutorial completion, replay, daily
      participation, and per-route completion and attempts, with counts.
   4. **Retention is unmeasured until this is done.**

## Gate 2: public launch with competitive boards (P1)

1. **Turn on the records service.**
   1. Add `FLY_API_TOKEN` and run the deploy workflow.
   2. Set `RECORDS_ENDPOINT`.
   3. Add `BACKUP_PASSPHRASE` so the nightly off-host backup runs.
   4. Check the first nightly run is green (the drill passed), then run one
      restore by hand from a downloaded artifact. Write the date in
      `server/deploy/README.md` ("Restore").
2. **Moderation rota.** Someone runs `admin.py reports` and
   `admin.py review` every few days.
3. **Stronger anti-cheat before boards are promoted publicly.** What is
   built stops edited saves, edited numbers, impossible or replayed climbs,
   and outlier times. Still to do, in order:
   1. **Play Integrity.** Attest the app on submission (a Google Cloud
      project, plus a verdict check in `service.py`). Refuse or hold
      records from unrecognised builds.
   2. **Server-side replay for the Crag.** Run the Godot simulation headless
      against the submitted log, as the expedition already sends its seed
      and decisions.
   3. **A server-side expedition replay** from the seed and decision list.
   4. **Tune the review thresholds** (`REVIEW_FASTER`, `REVIEW_POINTS`)
      from real beta times.
4. **Store listing and policy:** `docs/release/README.md` steps 4–6. That
   covers the Play Console, Data safety, content rating and the closed
   track.

## Later (P2)

- **A native iOS build** after Android is validated
  (`docs/release/ios-plan.md`): Apple developer account, a Mac or CI with
  Xcode, signing, TestFlight, and haptics and safe areas checked on
  iPhones.
- **Monetization and community donations**, decided against the
  retention numbers (`docs/monetization-and-donations.md`).
- **Content:** more crags and routes, a second mountain. The Expo
  prototype's Everest data is a starting point.
- **Art and sound:** replace the generated placeholders (`docs/art-brief.md`).
- **Housekeeping:** retire the Expo prototype once the engine parity test
  is no longer needed. The Godot engine has its own fixtures by then.
