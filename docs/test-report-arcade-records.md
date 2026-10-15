# Test report: Arcade Replayability and Competitive Records sprints

Branch `ccr-b5506e55-rahee5`.

## Results

| Suite | Result |
| --- | --- |
| Godot headless, all suites (`godot --headless --path godot res://tests/runner.tscn`) | **157 passed, 0 failed.** One of the 157 is the live-server sync test, which skips itself (and counts as passed) when no server is set. |
| The same sync test with `RECORDS_SERVER` pointing at the reference server on this machine | Passed: account made, a real climb synced, accepted, and read back from the global board |
| Reference server (`python3 -m unittest discover -s server/records_service/tests -t .`) | **26 passed** |
| Android export | Built and signed (size in the build log) |

Every existing Crag and Expedition test still passes.

## Arcade loop (`tests/test_arcade.gd`)

| What | How it is tested |
| --- | --- |
| Retry state resets | After Retry: no brief, the climber not locked, same shoes. A new level is created, so no state is carried over. |
| Attempts counted once | Attempts go 1 → 2 on one retry and reach 21 after 20 retries. `instant_retry_tapped`, `route_replayed` and `retry_time_ms` are each logged once per retry. |
| Retry time | 114–116 ms tap-to-playable, measured headless on a desktop. **Not measured on Android hardware.** |
| Repeated retries (leaks, stuck input) | 20 retries: the node count stays flat, and with no input the climber does not move afterwards. |
| Results order | Fall short: Retry first. First send: Next route first, Replay second. The results show time, falls, grade and best style. |
| High point and near-miss | A first go sets a high point but does not beat one. Above the best: NEW HIGH POINT (logged once). One row short: "Just 0.5 m short of your best". Far below: no message. Near the top: the anchor distance. A send: never a near miss. The chalk mark stays off every climbable cell. |
| Quick start | On a replay of the lesson, tips seen before become reminders and no longer stop the game. The first go still stops for every tip. |
| Daily | Retry works on the daily route. The day's high point and attempts are kept separately from the routes'. The results show the day's goes. |
| Skip celebration | One tap opens the results at once. |
| Lead falls | Unchanged: the existing lead-fall, ground-fall, clip and rope tests pass. |

## Records (`tests/test_records.gd`, `server/records_service/tests`)

| What | Where | How |
| --- | --- | --- |
| Ties | client and server | Equal values share a rank (1, 1, 3), and the earlier is listed first. A player's best counts once on a board. |
| Duplicate submissions | client and server | Each queued attempt has a unique id. The server answers a repeat with the original reply and stores it once. |
| Offline sync | client (fake network and the live reference server) | Offline: nothing sent, nothing verified. A network failure stops the round with nothing lost; the next round sends all; nothing is sent twice. Refusals keep their reason. Queue state persists. |
| Late offline dailies | server | Two days late is accepted on that day's board; three days late is refused. |
| Cheating attempts | server (tampered copies of real game submissions) | Each of these is refused with a reason: a shorter time than the log, an impossibly fast send, a missing bolt, a send without every bolt, events out of order, hidden falls, another map, an unknown route, a forged expedition score, a padded ledger, a clock from the future. A claimed style is ignored and recomputed. More than 30 submissions a minute is refused, then allowed again. |
| Tampered local file | client | Impossible goes are dropped, a non-number best is reset, unknown routes are dropped, scores are clamped, and a string is not a completion. Nothing loaded is ever verified. |
| First verified records | server | Decided by the server's time, not the device's. The first expedition completion goes to the first to arrive. A deleted account's first stays, anonymised. |
| Record persistence | client | Save, load and a round trip of the queue. First-ascent and first-completion dates never move. |
| Privacy and age | server and client | Under 13: no name, private, no friends, not on boards. Names are unique ignoring case and spacing. An age is required. Export and delete work, and the token stops working after deletion. |
| Screens | client | Every board and scope renders. Friends and Global say "not connected". Every view says "this device, not verified". A share card is made. |
| Results | client | A real second send shows "New personal record: fastest clean ascent 1:10 (was 1:20)" and "Rank: 1st of your 2 sends (this device)". |

## Not verified (needs a phone, a service or people)

- **Retry under one second on representative Android hardware.** Measured
  only on a headless desktop (116 ms). Check with the APK on a mid-range
  phone.
- **Touch and feel on a device:**
  - the chalk mark does not get in the way of touch controls or holds on
    a small screen;
  - the new sounds' loudness;
  - vibration on the new-record and high-point cues;
  - reduced-motion behaviour on a phone.
- **Online leaderboards in production.** No service is deployed and there
  are no credentials, so Global and Friends are not connected in the
  shipped build. Only a local end-to-end run against the reference server
  was done. Untested:
  - real network conditions;
  - TLS;
  - account recovery;
  - moderation.
- **Anti-cheat strength.** The checks stop edited saves, impossible times
  and forged scores or styles. A modified client faking a consistent,
  possible log is not caught. Server-side replay and platform attestation
  are documented next steps.
- **Legal and compliance.** The age thresholds per country (GDPR digital
  consent age), the privacy policy and the store data-safety forms need
  review before the online service is enabled.
- **Assisted-play rankings.** The board is kept separate, but the game
  has no assist options yet, so it is empty.
- **World Passport global ranking.** It only starts once a second
  continent has places; today there is one (Africa).
