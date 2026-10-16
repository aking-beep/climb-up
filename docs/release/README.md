# CLIMB UP closed beta: release kit

| Doc | What it covers |
| --- | --- |
| [beta-readiness-report.md](beta-readiness-report.md) | The audit: every item PASS / FAIL / BLOCKED / NOT TESTED, evidence, defects, GO/NO-GO |
| [android-signing.md](android-signing.md) | Package identity, upload key, Play App Signing, building the APK and AAB |
| [device-test-matrix.md](device-test-matrix.md) | The phones to test on and what to check (none tested yet) |
| [data-safety.md](data-safety.md) | Answers for Play's Data safety form |
| [age-and-moderation.md](age-and-moderation.md) | Age gate, consent, deletion, recovery, name moderation: what is enforced and what is open |
| [play-listing.md](play-listing.md) | Store text, assets, release notes, closed-test setup |
| [ios-plan.md](ios-plan.md) | The native iOS build: what exists, what it needs, when (after Android) |
| [`../monetization-and-donations.md`](../monetization-and-donations.md) | What will never be sold, the options, and the retention gate that unlocks the choice |
| [`../../server/deploy/README.md`](../../server/deploy/README.md) | Deploying the records service: HTTPS, storage, backups, moderation |
| [`../../server/deploy/site/privacy.html`](../../server/deploy/site/privacy.html) | The privacy policy (served at `/privacy`) |

## Go-live checklist (what is left, in order)

Everything that can be automated is: GitHub Actions builds, signs, checks
and can upload the game, and deploys the records service. The steps
below need your accounts. Each takes minutes.

1. **Records service on Fly.io** (about $2–5/month).
   1. Make a Fly.io account and add a payment card.
   2. Create a token: fly.io → Account → Access Tokens → Create token.
   3. In GitHub, add the repository secret **`FLY_API_TOKEN`**:
      Settings → Secrets and variables → Actions → New repository
      secret.
   4. Run the **Deploy records service** workflow (Actions tab →
      Run workflow). It prints the address, e.g.
      `https://climbup-records-arc.fly.dev`, after checking `/healthz`
      and `/privacy`.
   5. Add the repository **variable** **`RECORDS_ENDPOINT`** with that
      address (same page, Variables tab).
   6. Add the repository secret **`BACKUP_PASSPHRASE`**: a long random
      passphrase, also kept in the password manager. The **Back up records
      service** workflow then runs every night. It downloads a backup, runs
      the restore drill on it, and keeps it encrypted for 14 days. Run it
      once by hand (Actions → Run workflow) and check it is green.
2. **Upload key** (once, on your own computer).
   1. Run `sh tools/release/make_upload_key.sh "CN=CLIMB UP, O=ARC Labs"`.
   2. It sets, or tells you how to set, the secrets
      `ANDROID_UPLOAD_KEYSTORE_BASE64`, `ANDROID_UPLOAD_KEY_ALIAS` and
      `ANDROID_UPLOAD_KEY_PASSWORD`.
   3. Back up the `.jks` and its password offline.
3. **Build the release.** Run the **Android** workflow (Actions → Android
   → Run workflow).
   - Download the `climb-up-aab` artifact.
   - `SIGNED_WITH.txt` must say "upload key".
   - The build talks to `RECORDS_ENDPOINT`.
4. **Google Play Console** ($25 one-time developer registration).
   1. Create the app `CLIMB UP` and opt in to Play App Signing.
   2. Fill in the store listing, Data safety, content rating and target
      audience (13+) from `play-listing.md` and `data-safety.md`.
   3. Under Testing → Closed testing, create the track and add testers.
   4. Upload the AAB by hand: the first upload of a new app must be
      manual.
   5. Optional, for later uploads from GitHub: add a service account as
      `PLAY_SERVICE_ACCOUNT_JSON`, then run the Android workflow with
      `play_track` set to `alpha`. Raise `ANDROID_VERSION_CODE` each
      time.
5. **Real phones.**
   - Play's pre-launch report runs the closed-test build on real devices
     automatically and shows crashes and screenshots.
   - Also install it on at least 2 phones of your own and go through
     `device-test-matrix.md`.
   - `tools/android/emulator_smoke.sh` runs the same checks as CI on a
     USB-connected phone.
6. **Moderation.** Every few days, check name reports and the records
   held as outliers:
   `fly ssh console -a climbup-records-arc -C "sh -c 'cd /app && python3 -m server.records_service.admin reports'"`
   and the same with `review`, then `approve <ref>` or `refuse <ref>`
   (`docs/records-backend.md` §3).
7. **Measure the beta.** Collect the testers' pasted usage logs and run
   `python3 tools/playtest/retention.py logs/ --testers testers.csv`
   (`docs/playtest-plan.md`, "Measurements").

## Deployment requirements (reference)

1. **A host and a domain** for the records service. Any Docker host with
   ports 80 and 443, and a DNS record for the domain. Run
   `RECORDS_DOMAIN=<domain> docker compose up -d --build` in
   `server/deploy/`.
2. **Off-host backups.** Copy the `records-backups` volume to object
   storage nightly.
3. **The publisher's details**: ARC Labs,
   arclabs@arctransformationgroup.com, effective 15 October 2026. They are
   already in the privacy policy and the listing.
4. **An upload key** made on a trusted machine (`android-signing.md`).
   Play App Signing turned on.
5. **A build environment that can reach `dl.google.com` and
   `maven.google.com`**, so Gradle can build the AAB. GitHub Actions can
   (`.github/workflows/android.yml`).
6. **The endpoint in the build.** Set `records/endpoint` and
   `records/privacy_url` in `godot/project.godot` under `[climb_up]`.
   Bump `version/code`. Run `tools/godot/export.sh android-aab`.
7. **Devices.** Run `device-test-matrix.md` on at least rows 1–4 before
   inviting testers.
8. **Moderation.** Someone checks name reports at least every few days
   (`admin.py reports`).
