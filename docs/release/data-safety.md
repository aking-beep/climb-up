# Google Play Data safety answers (closed beta)

These answers describe build `0.9.0-beta.1` (9). They come from the code:
- `core/records/online.gd` is the only network code;
- `core/analytics/analytics.gd` has no sink, so analytics never leave
  the device;
- `server/records_service/service.py` is what the server stores.

Re-check them whenever the game or the service starts collecting
something new.

**Privacy policy URL:** `https://<records domain>/privacy`
(`server/deploy/site/privacy.html`).

## Overview

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** (only with an optional online account) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS only: `Online.endpoint_ok` refuses plain http off the device) |
| Do you provide a way for users to request that their data is deleted? | **Yes**: in the app (Records → My account → Delete my online account). The web route: email the support contact |

## Data types

| Play data type | Collected? | Shared? | Optional? | Purpose | Notes |
| --- | --- | --- | --- | --- | --- |
| Personal info → Name | Yes | No | Optional | App functionality | A public display name the player chooses. Not a real name; can be left empty |
| Personal info → User IDs | Yes | No | Optional (only with an account) | App functionality, Fraud prevention, security and compliance | A random player id and account token, made by the server |
| Personal info → Other info | Yes | No | Optional | App functionality | Age group (under 13 / 13–17 / adult), derived from the age entered. The age itself is not stored |
| App activity → In-app actions / Other user-generated content | Yes | No | Optional | App functionality, Fraud prevention | Finished climbs: route, time, falls, height, move log; expedition score. Reports of names |
| App activity → Other actions | Yes | No | Optional | App functionality | The friends list (friend codes added) |
| Location, Contacts, Photos, Audio, Files, Calendar, Messages, Health, Financial info, Web browsing, Email | **No** | | | | |
| App info and performance → Crash logs / Diagnostics | **No** | | | | The local usage log never leaves the device |
| Device or other IDs | **No** | | | | No advertising id and no Android id. The server keeps client network addresses in memory for one hour for rate limiting. They are never stored |

"Shared" means given to a third party. Nothing is shared. Public names
and records show on leaderboards to other players by the player's own
choice (visibility). Play treats that as part of app functionality, not
as sharing.

## Other declarations

- **Ads:** none. Declare "No, my app does not contain ads".
- **Target audience and content:**
  - Recommended target age: **13+** (13–15, 16–17, 18+).
  - Under-13s can play offline, but online accounts are refused (see
    `age-and-moderation.md`).
  - Don't opt into the Families program for the beta.
- **App access:** everything works without signing in. Online records
  need a free account the reviewer can create in the game (age 18+, any
  name). No credentials are needed.
- **Government, financial, health features:** none.
- **Permissions:**
  - `INTERNET` and `ACCESS_NETWORK_STATE`: online records.
  - `VIBRATE`: haptics, which can be turned off in Settings.
