# Age protections, consent, deletion and name moderation: review

What the beta does, where it is enforced, and what is still open.
- **Client:** `godot/core/records/online.gd`,
  `godot/modes/records/account_screen.gd`.
- **Server:** `server/records_service/service.py`,
  `server/records_service/admin.py`.

## Age

| Rule | Client | Server | Tested |
| --- | --- | --- | --- |
| An account needs an age, asked neutrally ("How old are you?", no default, no hint which answer unlocks what) | `account_screen.gd` | `create_player` returns 400 without an age | `test_online` › sign-up; `test_service` › `test_an_age_is_needed` |
| Under 13: no online account, nothing sent. The device remembers the answer (`underAge`) and doesn't ask again | `Online.register` | Under-13 accounts are private, with no name, friends or boards (defence in depth) | `test_online` › sign-up; `test_service` › `test_under_13_stays_private` |
| 13–17: friends-only by default; can't be seen on Global boards unless they choose public | | `visibility="friends"` | `test_online` (Cyd, 16, is not on the global board) |
| Adults: public by default; can set friends or private | | `PATCH /v1/me` | `test_service` |

**Open items:**
- The age gate takes the player's word. That is normal for a 13+ game,
  but it is not verification.
- GDPR lets EU countries set the age of digital consent up to 16. The
  beta treats 13–15 like 16–17 (friends-only, no ads, no sharing). Before
  an EU launch, decide per country whether 13–15s need parental consent.

## Consent

- Nothing leaves the device until the player:
  - creates an account;
  - ticks "I agree to the privacy policy" (`account_screen._create`
    refuses without it, tested).
- The sign-up screen summarises what is kept (`PRIVACY_SUMMARY`). It
  links to the full policy when `climb_up/records/privacy_url` is set.
- Usage analytics stay on the device. `Settings.share_usage` defaults off,
  and no sink exists.

## Deletion and recovery

| Action | Where | Effect | Tested |
| --- | --- | --- | --- |
| Delete online account | Account screen, two taps | `DELETE /v1/me`: removes the account, climbs, submissions, friends both ways, and reports made. Firsts stay as "a deleted account". Signs out | `test_online` (Cyd, Bea, Ann), `test_service` |
| Export | `GET /v1/me/export` | Everything held, as JSON | `test_service` |
| Delete local records | Records screen, two taps | Clears the on-device records file | `test_records` |
| Sign out | Account screen | Forgets the token on this device; the account stays | |
| Recover | Account screen → "Copy my recovery code" / "Restore my account" | The token restores the account on another device (`GET /v1/me`) | `test_online` › restore; `test_operations` › recovery |

**Open items:**
- The recovery code is the account token: anyone holding it controls the
  account. The screen says so.
- There is no way to rotate a token. If a code leaks, the player deletes
  the account and makes a new one.
- Backups keep deleted data for up to 14 days. The policy says so.

## Name moderation

| Safeguard | Where |
| --- | --- |
| 3–16 characters, letters, numbers, spaces, `-` and `_`; unique ignoring case and separators | client `Online.name_problem`, server `name_problem`, `name_key` |
| Blocked words: reserved names (admin, support, official…) and a starter list of slurs and sexual or violent words, matched inside the name; extra words from `blocked-words.txt` without a code change | `service.BLOCKED`, `RECORDS_BLOCKED_WORDS` |
| Report a name: a Report button beside other players on the online boards; 10 reports per player per day | `records_screen._entry`, `POST /v1/reports` |
| Moderator tools: list open reports with counts, hide a name (shown as "a climber" everywhere, including firsts; the name is freed), ban (submissions refused, off every board, reversible), resolve | `admin.py`; `test_operations` |
| Under-13s and private players never show a name | `_public_name` |

**Open items:**
- Matching words inside names can block innocent ones ("Essex" contains
  "sex"). That is acceptable for a beta: the player picks another name.
- No automatic review. A person must check the reports. During the beta,
  check them at least every few days (`server/deploy/README.md`).
- There is no chat or free text anywhere else in the game, so names are
  the only user-generated text.

## Abuse limits

- 30 new accounts per address per hour.
- 30 submissions per player per minute.
- 256 KB request cap at both the proxy and the service.
- Anti-cheat validation of every submission (`validate.py`). It stops
  casual cheating, not a modified client (`docs/records-backend.md` §3).
