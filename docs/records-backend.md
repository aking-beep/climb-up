# Records and leaderboards: architecture and backend

**Status.** Local records and the leaderboard screens are in the game.
The online service has a reference implementation with tests
(`server/records_service`), and the game's client has been checked
against it end to end on a developer machine. **The service is not
deployed and there are no production credentials.**

So the shipped build:
- shows Global and Friends boards as "not connected";
- labels every record "this device, not verified";
- never invents names, numbers or ranks.

## 1. The Godot side as it stands

| Piece | Where | What it does |
| --- | --- | --- |
| `Crag` (autoload) | `modes/crag/crag.gd` | Route progress: attempts, sends, best style and time, high point, the daily route, `retry()` |
| `CragLevel` | `modes/crag/crag_level.gd` | One attempt. Keeps `attempt_log`: tie-in, clips, falls, rests, catches, height every second, end |
| `Expedition` (autoload) | `modes/expedition/expedition.gd` | The running expedition. `_report_end()` fires once per finished expedition |
| `ExpeditionEngine.score` | `modes/expedition/engine/expedition_engine.gd` | The score (judgment, risk, teamwork, preparation; completion bonuses) |
| `Records` (autoload, new) | `core/records/records.gd` | Personal records, ranks, the World Passport, the offline queue, share text, delete |
| `Online` (new) | `core/records/online.gd` | The service client: HTTP, account, name rules, age rules. Inactive without a configured endpoint and token |
| Records screen (new) | `modes/records/records_screen.gd` | Crag / Expedition / Passport × Personal / Friends / Global |

Saves are JSON under `user://`. Records live in their own file
(`climb_up_records.json`), so deleting them never touches game progress.

## 2. The minimal backend

The smallest service that can verify records honestly:

- **One process, one database.** A small HTTP JSON API over SQLite (or
  Postgres when it grows). The reference implementation uses the Python
  standard library only (`sqlite3` and `wsgiref`); in production, put it
  behind a TLS-terminating proxy.
- **Anonymous device accounts.** The server issues the player id and a
  secret token. Only a SHA-256 hash of the token is stored. No email or
  password is needed to play.
- **Submit attempts, not scores.** The client sends what happened (the
  event log, or the expedition's final state). The server recomputes:
  - the style, from its own count of earlier attempts;
  - the time ranks;
  - the expedition score.
- **Server time decides "first".** The first verified ascent of a route,
  and the first verified expedition completion, belong to whichever
  accepted attempt *arrived* first by the server's clock (an
  `INSERT OR IGNORE` on a primary key). Device clocks are ignored.

### API (v1)

| Method | Path | Body / query | Returns |
| --- | --- | --- | --- |
| POST | `/v1/players` | `{age, displayName?}` | `{playerId, token, friendCode, visibility, publicName}` |
| PATCH | `/v1/me` | `{displayName?, visibility?}` | `{ok}` |
| GET | `/v1/me/export` | | everything held about the player |
| DELETE | `/v1/me` | | 204 |
| POST | `/v1/friends` | `{friendCode}` | `{ok}` |
| POST | `/v1/submissions` | `{id, kind: crag\|expedition, clientTime, payload}` | `{ok, verified, serverTime, style, rank, cleanRank, firstVerifiedAscent}`, or `{ok:false, reason}` |
| GET | `/v1/leaderboards/crag/<route>` | `board=time\|clean`, `scope=global\|friends` | `{entries:[{rank, player, seconds, received}]}` |
| GET | `/v1/leaderboards/daily/<YYYY-MM-DD>` | `scope` | the same shape |
| GET | `/v1/leaderboards/expedition/<standard\|hard\|hardest>` | `assisted=0\|1`, `scope` | `{entries:[{rank, player, score, complete}]}` |
| GET | `/v1/firsts` | | `{firsts:[{scope, display, received}]}` |

All requests except creating an account and reading the boards send
`Authorization: Bearer <token>`.

### Data model

- `players(id, token_hash, created, age_group, display_name, name_key UNIQUE, visibility, friend_code UNIQUE)`
- `submissions(player_id, id, kind, received, status, reason, reply)`, with primary key `(player_id, id)`. This is the idempotency record.
- `crag_attempts(player_id, sub_id, board, sent, seconds, falls, rows, style, received)`. `board` is the route id, or `daily:<date>`.
- `expedition_runs(player_id, sub_id, difficulty, assisted, score, complete, received)`
- `firsts(scope PRIMARY KEY, player_id NULL, display, received)`. Scopes are `crag:<board>` and `expedition:complete`.
- `follows(player_id, friend_id)`

### Crag submission payload (built by `Records`)

```json
{"route": "warm-up", "date": "", "mapHash": 878098442, "beta": false,
 "go": {"sent": true, "seconds": 29, "falls": 0, "rows": 31, "style": "onsight", "shoes": "neutral"},
 "events": [[0.0, "tie_in", "neutral"], [1.02, "h", 0], [3.4, "clip", [0, 1]], ..., [29.1, "end", ["top", 31, 0]]]}
```

`mapHash` is FNV-1a of the route's map text, the same function the daily
generator uses. The server's route data comes from the game itself
(`godot/tests/export_routes.tscn`), so geometry can never drift.

## 3. Integrity (basic anti-cheat)

The server refuses an attempt when any of these holds:

- **Unknown or mismatched route.** The route is unknown, or the map hash
  differs (an old or modified client).
- **Bad event log.**
  - It doesn't start at the tie-in or end with an end event.
  - Its times run backwards, or an event comes after the attempt's end.
  - Its height goes down.
- **Impossible climbing.**
  - Height rises faster than 3.5 rows/s, plus a dyno's jump around a
    catch. The game's fastest climbing is 2.8 rows/s.
  - A send is faster than the route's height at that speed.
- **Bolts.** They are clipped out of order or from the wrong height, or
  a send doesn't clip every bolt.
- **Falls.** The fall count differs from the falls in the log, or
  exceeds what the route allows.
- **Expedition.**
  - The score differs from the server's recomputation (`validate.score`,
    a port of `ExpeditionEngine.score`).
  - A stat is out of range.
  - The ledger has oversized or repeated entries.
  - The run claims a summit below the crater rim.
- **Clock and volume.** The device clock is more than 10 minutes ahead,
  or the player sends more than 30 submissions a minute (answered with
  429, retry later).

Other protections:
- **Duplicates.** The same submission id gets the same answer again and
  is counted once.
- **Offline play.** A daily go may arrive up to 2 days late and still
  counts for its day. After that its board is closed.

**Limits (stated plainly).** These checks stop casual cheating:
- edited saves;
- edited numbers;
- impossible times;
- forged styles and scores.

A modified client that fabricates a consistent, physically possible event
log can still pass, and the beta flag is the client's word. To go
further:
- replay the attempt server-side, by running the Godot simulation
  headless against the log;
- sign builds with platform attestation (Play Integrity / App Attest);
- have moderators review outliers.

Expeditions also carry the seed and the decision list, so a full
server-side replay can be added without changing the client.

## 4. Offline and local records

The local and verified records are separate:

- Every finished attempt updates the local records at once and waits in
  the queue (`Records.data.queue`), each with a unique id.
- `Records.sync()` sends pending entries when a service is configured.
  - A network failure, a 5xx or a 429 stops the round, and nothing is
    lost.
  - A refusal is kept with its reason.
  - An acceptance is stored with the server's time.
- Nothing on the device is ever shown as verified.
- The records file is cleaned on load: malformed entries are dropped,
  scores are clamped, and nothing loaded is treated as verified.

## 5. Privacy and age

- **Age first.** An account needs an age.
  - Under 13: no public name, no friends, no global boards; records stay
    private (`visibility=private`, enforced by the server).
  - 13 to 17: friends-only by default.
  - Adults: public by default.

  Where a country sets a higher age of digital consent (GDPR allows up to
  16), configure the threshold per country before launch.
- **Names.** 3 to 16 characters and unique, ignoring case, spaces, `-`
  and `_`. Reserved words are blocked. A real deployment needs a
  moderation word list and a report button.
- **Export and delete.** `GET /v1/me/export` returns everything held.
  `DELETE /v1/me` removes the account, its attempts, follows and
  submissions. A first ascent it held stays on the record as "a deleted
  account", so a first stays a first with no personal data left.
- **On the device.** "Delete my records on this device" on the records
  screen. Usage analytics stay local unless the player opts in
  (`Settings.share_usage`, unchanged).
- **Free for everyone.** No paid tier or advantage touches records or
  ranking.

## 6. Deploying it (what is needed, and rough costs)

Requirements:
- **Hosting.** A host for one small Python process: a small VM or a
  container service, for example Fly.io, Render, Railway, a cloud VM, or
  a home server for testing.
- **TLS.** A domain with HTTPS (Let's Encrypt or the host's).
- **Database.** SQLite on a persistent volume, with daily backups.
  Postgres becomes worth it once you run more than one instance.
- **Route data.** Regenerate `data/routes.json` for each release and each
  day ahead:
  `godot --headless --path godot res://tests/export_routes.tscn -- out=$PWD/server/records_service/data/routes.json from=YYYY-MM-DD days=N`.
  Run it from a daily job (cron) so daily routes exist before players
  submit.
- **Turning it on in the client.** Store `{endpoint, token, playerId}` in
  `user://climb_up_online.json`; `Online.register()` does this. Add a
  sign-up screen, with age first, before shipping it.
- **Policy.** A privacy policy and terms naming what is collected. These
  are needed before any store release that turns it on.

Approximate monthly cost at small scale (estimates, not quotes; check
current pricing):

| Item | Low traffic |
| --- | --- |
| One small VM or container with a persistent volume | about $5–15 |
| Managed Postgres (only if needed) | about $0–25 |
| Domain | about $1 (around $12 a year) |
| Backups and object storage | about $1 |

At hobby scale that is roughly $5–40 a month. Load is tiny per player:
one submission of a few KB per finished attempt.

## 7. Running it

```sh
python3 -m server.records_service.service --db records.sqlite --port 8080
python3 -m unittest discover -s server/records_service/tests -t .
# The game's end-to-end sync test against a running server:
RECORDS_SERVER=http://127.0.0.1:8080 godot --headless --path godot res://tests/runner.tscn -- only=test_records
```
