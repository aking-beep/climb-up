# Google Play closed test: listing, assets and release notes

## Assets (in `store/`)

| Asset | File | Spec | Source |
| --- | --- | --- | --- |
| App icon | `store/icon-512.png` | 512 × 512 PNG, 32-bit | `tools/art/app_icon.py` |
| Feature graphic | `store/feature-graphic-1024x500.png` | 1024 × 500 PNG, no alpha | `tools/art/feature_graphic.py` (the summit sunrise, from the game) |
| Phone screenshots | `store/screenshots/1-summit-sunrise.png`, `2-crag-lions-roof.png`, `3-camp-decisions.png`, `4-lava-tower.png`, `5-title.png` | 1440 × 810 (16:9) PNG | `godot/tests/shot.tscn`, rendered by the game (desktop, OpenGL) |

The screenshots are real frames from the current build, rendered on a
desktop. They were not captured on a phone. Before an open or production
release, replace them with captures from a reference phone.

## Store listing text

**App name:** CLIMB UP

**Short description** (80 characters max):
> Climb crag routes and lead a team up Kilimanjaro. Bring everyone home.

**Full description:**
> CLIMB UP is two climbing games in one.
>
> CRAG: short sport routes on one cliff. Learn to read holds, clip bolts,
> rest on good jugs and time your dynos. Every route has a best time, a
> clean ascent and a style: onsight, flash or redpoint. A new Daily Crag
> route every day. Retry instantly.
>
> EXPEDITION: Kilimanjaro with a team of four, on a 13, 9 or 8 day
> permit. Plan each day at camp: pace, rest, food, acclimatisation and when to turn
> back. Then climb the Lava Tower, the Barranco Wall and the long summit
> night yourself. See the sun rise from Uhuru Peak, and get everyone home
> safely. The summit is only half of it.
>
> RECORDS: personal records on your device. With a free online account
> (no email) you can be on the Global and Friends leaderboards. Records
> are checked by the server, and the first verified ascent of each route
> is kept.
>
> No ads. No purchases. Play offline.

**Category:** Game → Adventure (alternative: Sports).
**Tags:** Climbing, Adventure, Strategy, Single player, Offline.
**Contains ads:** No. **In-app purchases:** No.
**Content rating questionnaire:** no violence, no blood, no gambling and
no user-to-user communication (names on leaderboards only). Expect
Everyone / PEGI 3. The game mentions altitude sickness as game fiction
(the cards say "Game fiction, not medical advice").

## Contact and support (fill in before submitting)

| Field | Value |
| --- | --- |
| Developer name | **[publisher name]** |
| Support email (required, public) | **[support email]** |
| Website (optional) | **[website]** |
| Privacy policy URL | `https://<records domain>/privacy` (`server/deploy/site/privacy.html`; fill in its publisher, contact and date first) |

The privacy page also needs the same publisher, contact and effective date.

## Closed test setup

1. Play Console → Testing → Closed testing → Create track (e.g. "beta").
2. Add testers by email list or Google Group. Share the opt-in link.
3. Countries: start with one or two. The age rules assume 13+; see
   `age-and-moderation.md` before EU countries where the age of digital
   consent is 14–16.
4. Upload `build/godot-android/climb-up.aab`. Build it with your upload
   key; see `android-signing.md`.
5. Complete these before review:
   - Data safety (`data-safety.md`);
   - content rating;
   - target audience: 13+;
   - app access: no login needed.

## Release notes: 0.9.0-beta.1 (9)

> First closed beta.
> - Crag: a lesson and 6 routes from 4 to 7a, plus the Daily Crag. Instant retry and personal records.
> - Expedition: the whole Kilimanjaro trek with three played climbs, the summit sunrise and the way down.
> - Online records (optional, 13+): Global and Friends boards, first verified ascents, friend codes,
>   recovery code, report a name, delete your account in the game.
> - Landscape, works offline. Your records wait on the device and are sent when you're back online.
>
> Please report bugs and anything that felt unfair to [support email].

## Beta tester instructions (for the opt-in page or email)

- Play both modes. Finish at least one Crag route and one Expedition
  climb.
- Optional: make an online account (Records → Global → Sign up). Add
  another tester's friend code, then check the Friends board.
- Try playing with flight mode on, then turn it off. Your climbs should
  appear on the boards.
- Tell us:
  - your phone model;
  - anything that stuttered, got hot or drained the battery fast;
  - any touch control that missed.
