# CLIMB UP closed beta: release kit

| Doc | What it covers |
| --- | --- |
| [beta-readiness-report.md](beta-readiness-report.md) | The audit: every item PASS / FAIL / BLOCKED / NOT TESTED, evidence, defects, GO/NO-GO |
| [android-signing.md](android-signing.md) | Package identity, upload key, Play App Signing, building the APK and AAB |
| [device-test-matrix.md](device-test-matrix.md) | The phones to test on and what to check (none tested yet) |
| [data-safety.md](data-safety.md) | Answers for Play's Data safety form |
| [age-and-moderation.md](age-and-moderation.md) | Age gate, consent, deletion, recovery, name moderation: what is enforced and what is open |
| [play-listing.md](play-listing.md) | Store text, assets, release notes, closed-test setup |
| [`../../server/deploy/README.md`](../../server/deploy/README.md) | Deploying the records service: HTTPS, storage, backups, moderation |
| [`../../server/deploy/site/privacy.html`](../../server/deploy/site/privacy.html) | The privacy policy (served at `/privacy`) |

## Deployment requirements (what the publisher must provide)

1. **A host and a domain** for the records service. Any Docker host with
   ports 80 and 443, and a DNS record for the domain. Run
   `RECORDS_DOMAIN=<domain> docker compose up -d --build` in
   `server/deploy/`.
2. **Off-host backups.** Copy the `records-backups` volume to object
   storage nightly.
3. **The publisher's details**: name, support email, effective date. Put
   them in `server/deploy/site/privacy.html` and in the Play listing.
4. **An upload key** made on a trusted machine (`android-signing.md`).
   Play App Signing turned on.
5. **A build environment that can reach `dl.google.com` and
   `maven.google.com`**, so Gradle can build the AAB. The cloud session
   used for this sprint could not; see the report.
6. **The endpoint in the build.** Set `records/endpoint` and
   `records/privacy_url` in `godot/project.godot` under `[climb_up]`.
   Bump `version/code`. Run `tools/godot/export.sh android-aab`.
7. **Devices.** Run `device-test-matrix.md` on at least rows 1–4 before
   inviting testers.
8. **Moderation.** Someone checks name reports at least every few days
   (`admin.py reports`).
