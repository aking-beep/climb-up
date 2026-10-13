# Analytics in CLIMB UP

Usage events are recorded **on the device only**. Nothing is sent
anywhere: there is no network code in `core/analytics/analytics.gd` and
no third-party SDK in the project. Usage measurement for playtests comes
from these local logs, which testers export by hand (see
`docs/playtest-plan.md`).

## What is recorded

Each event is one JSON line in `user://climb_up_events.jsonl` (the newest
2,000 kept):

```json
{"e": "route_completed", "t": 1791892800, "s": "9f2c4a1be07d3355", "p": {"route": "warm-up", "style": "onsight", "falls": 0, "seconds": 41}}
```

- `e`: the event name, from a fixed list (anything else is dropped).
- `t`: Unix time, to the second.
- `s`: a session id, 8 random bytes made at launch. It is not derived
  from the device, the account, the advertising id or anything else, and
  it changes every launch.
- `p`: a few game facts. Only plain values (numbers, text, true/false);
  anything else is dropped.

No names, emails, device ids, IP addresses, locations, contacts or
advertising ids. The player can turn the log off (Settings → "Usage log
on this device"); then nothing is written.

| Event | When | Properties |
| --- | --- | --- |
| `game_launched` | app start | platform, build |
| `session_ended` | app to background, focus lost, or quit | seconds in the foreground this session |
| `mode_selected` | title: Crag or Expedition | mode |
| `tutorial_started` | first tie-in on First Climb | |
| `tutorial_completed` | first send of First Climb | seconds, falls |
| `route_started` | tie-in on a crag route | route, attempt |
| `route_replayed` | tie-in on a route already tried | route, sent_before |
| `route_failed` | lowered off or too many falls | route, bolts, falls, seconds |
| `route_completed` | reached the anchor | route, style, falls, seconds |
| `daily_started` / `daily_completed` | the daily route | attempt / date, style, falls, seconds |
| `daily_shared` | share tapped | date |
| `achievement_earned` | a new achievement | id |
| `expedition_started` | new expedition | seed |
| `expedition_abandoned` | a new one started over one under way | checkpoint, day |
| `expedition_completed` | the expedition ended (home or not) | returned, summit, overall, day, descent_played |
| `descent_completed` | the way down landed | result, slips, assisted |
| `settings_changed` | a setting changed | setting |

## Connecting a provider later (with consent)

1. Add a consent screen shown once, before anything is sent, saying
   what is sent, why, and to whom, with "No" as easy as "Yes". Store the
   answer in `Settings.share_usage` (it exists and is always `false`
   today) and let the player change it in Settings.
2. Write a sink: a function that takes one event dictionary and queues it
   for the provider (batch it, send over HTTPS, drop on failure, never
   block the game). Register it with `Analytics.add_sink(callable)`.
   `Analytics.event()` only calls sinks when `Settings.share_usage` is
   true, and a test checks that no sink hears anything without it.
3. Pick a provider that can run without device identifiers and lets you
   delete data on request. Check the store rules (Google Play Data
   safety, Apple privacy labels) and local law (GDPR, COPPA if children
   may play) before shipping.
4. Keep the event list in `Analytics.EVENTS` as the contract: a new event
   is a reviewed change to that list and to this table.

## For the leaderboard later

Daily results already have a server-checkable shape (`Daily.payload()`:
date, version, seed, the route's hash, the go). A leaderboard needs a
trusted backend to receive and verify these, plus an account or anonymous
id the player agrees to; none of that exists yet, and the game claims no
rankings.
