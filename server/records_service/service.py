"""The CLIMB UP records service.

Python standard library only (sqlite3 + wsgiref), so it runs anywhere:

    python3 -m server.records_service.service --db records.sqlite --port 8080

In production (deploy/README.md) it runs behind a TLS proxy (Caddy) with the
database on a persistent volume, configured from the environment:
RECORDS_DB, RECORDS_PORT, RECORDS_BIND, RECORDS_TRUST_PROXY (read the
client address from X-Forwarded-For), RECORDS_BLOCKED_WORDS (a file of
extra words names may not contain), RECORDS_ACCOUNTS_PER_HOUR (new
accounts allowed from one address in an hour), RECORDS_PRIVACY_FILE (an
HTML page served at /privacy), RECORDS_BACKUP_DIR and RECORDS_BACKUP_KEEP
(daily backups made by the service itself, for single-machine hosts). Every request is logged as one JSON
line (no tokens, no addresses). GET /healthz checks the database.

Accounts are anonymous device accounts: the server makes the player id and
a secret token (stored only as a hash). Display names are unique without
case, spaces, '-' or '_'. Under-13 accounts get no public name, no friends
and no global boards. Time comes from the server's clock: "first verified"
is the earliest server time an accepted attempt arrived, whatever the
device's clock said. Deleting an account deletes its attempts; a first
ascent it held stays on the record, anonymised.

API (JSON over HTTPS in production; docs/records-backend.md):
  POST   /v1/players                       {age, displayName?} -> {playerId, token, friendCode}
  PATCH  /v1/me                            {displayName?, visibility?}
  GET    /v1/me/export                     everything held about the player
  DELETE /v1/me                            delete the account
  POST   /v1/friends                       {friendCode}
  POST   /v1/submissions                   {id, kind, clientTime, payload} -> {ok, serverTime, ...}
  GET    /v1/leaderboards/crag/<route>?board=time|clean&scope=global|friends
  GET    /v1/leaderboards/daily/<date>?scope=global|friends
  GET    /v1/leaderboards/expedition/<difficulty>?assisted=0|1&scope=global|friends
  GET    /v1/firsts
  GET    /v1/me                            the signed-in player (restoring an account from its recovery code)
  POST   /v1/me/rotate                     a new recovery code (token); the old one stops working
  POST   /v1/reports                       {player, reason} report a public name
  GET    /healthz                          {ok, version} for the load balancer
"""

import hashlib
import json
import os
import re
import secrets
import sqlite3
import sys
import threading
import time
from urllib.parse import parse_qs

from . import validate

MIN_PUBLIC_AGE = 13
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 _-]{2,15}$")
VERSION = "1.1.0"
## Words a public name may not contain: the reserved ones, a starter list of
## slurs and obvious abuse, and any listed in RECORDS_BLOCKED_WORDS.
BLOCKED = ("admin", "moderator", "official", "climbup", "support", "staff",
           "fuck", "shit", "cunt", "nigg", "fag", "rape", "nazi", "hitler", "porn", "sex", "kill")
# New accounts from one address in an hour (RECORDS_ACCOUNTS_PER_HOUR).
# Generous: players on one mobile carrier or school network share an address.
ACCOUNTS_PER_HOUR = 30
REPORTS_PER_DAY = 10     # reports from one player in a day
RATE_LIMIT = 30          # submissions
RATE_WINDOW = 60         # seconds
LATE_DAILY_DAYS = 2      # an offline daily go may arrive this many days late
FUTURE_SLACK = 600       # a device clock this far ahead is refused

SCHEMA = """
CREATE TABLE IF NOT EXISTS players (
  id TEXT PRIMARY KEY, token_hash TEXT UNIQUE NOT NULL, created INTEGER NOT NULL,
  age_group TEXT NOT NULL, display_name TEXT, name_key TEXT UNIQUE,
  visibility TEXT NOT NULL, friend_code TEXT UNIQUE NOT NULL);
CREATE TABLE IF NOT EXISTS submissions (
  player_id TEXT NOT NULL, id TEXT NOT NULL, kind TEXT NOT NULL, received INTEGER NOT NULL,
  status TEXT NOT NULL, reason TEXT, reply TEXT, PRIMARY KEY (player_id, id));
CREATE TABLE IF NOT EXISTS crag_attempts (
  player_id TEXT NOT NULL, sub_id TEXT NOT NULL, board TEXT NOT NULL, sent INTEGER, seconds INTEGER,
  falls INTEGER, rows INTEGER, style TEXT, received INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS expedition_runs (
  player_id TEXT NOT NULL, sub_id TEXT NOT NULL, difficulty TEXT, assisted INTEGER, score INTEGER,
  complete INTEGER, received INTEGER NOT NULL, points INTEGER);
CREATE TABLE IF NOT EXISTS firsts (
  scope TEXT PRIMARY KEY, player_id TEXT, display TEXT, received INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS follows (
  player_id TEXT NOT NULL, friend_id TEXT NOT NULL, PRIMARY KEY (player_id, friend_id));
CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT, reporter TEXT NOT NULL, target TEXT NOT NULL,
  reason TEXT, created INTEGER NOT NULL, resolved INTEGER NOT NULL DEFAULT 0);
"""

_extra_blocked = ()


def load_blocked_words(path):
    """Extra blocked words from a file, one a line (lines starting # skipped)."""
    global _extra_blocked
    if path and os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            _extra_blocked = tuple(w.strip().lower() for w in f if w.strip() and not w.startswith("#"))


def name_key(name: str) -> str:
    return re.sub(r"[ _-]", "", name.strip().lower())


def name_problem(name: str) -> str:
    n = name.strip()
    if not NAME_RE.match(n):
        return "Names are 3 to 16 letters, numbers, spaces, - or _, starting with a letter or number."
    if any(w in name_key(n) for w in BLOCKED + _extra_blocked):
        return "That name is reserved."
    return ""


class Service:
    def __init__(self, db=":memory:", clock=None):
        self.db = sqlite3.connect(db, check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        # One writer at a time (the HTTP server is threaded): requests hold
        # this lock. WAL keeps reads and the backup job from blocking writes.
        self.lock = threading.RLock()
        if db != ":memory:":
            self.db.execute("PRAGMA journal_mode=WAL")
            self.db.execute("PRAGMA synchronous=NORMAL")
            self.db.execute("PRAGMA busy_timeout=5000")
        self.db.executescript(SCHEMA)
        pcols = [r[1] for r in self.db.execute("PRAGMA table_info(players)")]
        # Moderation: a banned player's records are refused and hidden; a
        # hidden name shows as "a climber".
        for col in ("banned", "name_hidden"):
            if col not in pcols:
                self.db.execute(f"ALTER TABLE players ADD COLUMN {col} INTEGER NOT NULL DEFAULT 0")
        self._new_accounts = {}
        self.accounts_per_hour = ACCOUNTS_PER_HOUR
        # Databases from before leader points: add the column (old runs
        # rank by their score).
        cols = [r[1] for r in self.db.execute("PRAGMA table_info(expedition_runs)")]
        if "points" not in cols:
            self.db.execute("ALTER TABLE expedition_runs ADD COLUMN points INTEGER")
        self.clock = clock or (lambda: int(time.time()))
        # The privacy policy, served at /privacy (bytes; None for none).
        self.privacy_page = None

    # --- accounts --------------------------------------------------------

    def create_player(self, body, address=""):
        # Throttle account creation per client address (kept in memory only).
        now = self.clock()
        if address:
            times = [t for t in self._new_accounts.get(address, []) if t > now - 3600]
            if len(times) >= self.accounts_per_hour:
                return 429, {"error": "too many new accounts from here; try again later"}
            times.append(now)
            self._new_accounts[address] = times
        age = body.get("age")
        if not isinstance(age, int) or age < 4 or age > 120:
            return 400, {"error": "an age is needed to set up privacy correctly"}
        group = "under13" if age < MIN_PUBLIC_AGE else ("teen" if age < 18 else "adult")
        name = body.get("displayName")
        key = None
        if name is not None:
            if group == "under13":
                return 403, {"error": "under 13: no public name, records stay private"}
            problem = name_problem(name)
            if problem:
                return 400, {"error": problem}
            key = name_key(name)
            if self.db.execute("SELECT 1 FROM players WHERE name_key=?", (key,)).fetchone():
                return 409, {"error": "that name is taken"}
        pid = secrets.token_hex(8)
        token = secrets.token_urlsafe(32)
        code = secrets.token_hex(4).upper()
        vis = "private" if group == "under13" else ("friends" if group == "teen" else "public")
        self.db.execute("INSERT INTO players (id, token_hash, created, age_group, display_name, name_key, visibility, friend_code) VALUES (?,?,?,?,?,?,?,?)",
                        (pid, _hash(token), self.clock(), group, name.strip() if name else None, key, vis, code))
        self.db.commit()
        return 201, {"playerId": pid, "token": token, "friendCode": code, "visibility": vis,
                     "publicName": group != "under13"}

    def player_for(self, token):
        if not token:
            return None
        return self.db.execute("SELECT * FROM players WHERE token_hash=?", (_hash(token),)).fetchone()

    def update_me(self, p, body):
        if "displayName" in body:
            if p["age_group"] == "under13":
                return 403, {"error": "under 13: no public name"}
            problem = name_problem(body["displayName"])
            if problem:
                return 400, {"error": problem}
            key = name_key(body["displayName"])
            row = self.db.execute("SELECT id FROM players WHERE name_key=?", (key,)).fetchone()
            if row and row["id"] != p["id"]:
                return 409, {"error": "that name is taken"}
            self.db.execute("UPDATE players SET display_name=?, name_key=? WHERE id=?", (body["displayName"].strip(), key, p["id"]))
        if "visibility" in body:
            if body["visibility"] not in ("public", "friends", "private"):
                return 400, {"error": "bad visibility"}
            if p["age_group"] == "under13" and body["visibility"] != "private":
                return 403, {"error": "under 13: records stay private"}
            self.db.execute("UPDATE players SET visibility=? WHERE id=?", (body["visibility"], p["id"]))
        self.db.commit()
        return 200, {"ok": True}

    def me(self, p):
        """The signed-in player: what a device restoring the account shows."""
        return 200, {"playerId": p["id"], "displayName": None if p["name_hidden"] else p["display_name"],
                     "friendCode": p["friend_code"], "visibility": p["visibility"], "ageGroup": p["age_group"],
                     "publicName": p["age_group"] != "under13", "banned": bool(p["banned"])}

    def rotate(self, p):
        """A new token (the recovery code) for this player; the old one stops
        working at once. For a code that was shared or seen by someone else."""
        token = secrets.token_urlsafe(32)
        self.db.execute("UPDATE players SET token_hash=? WHERE id=?", (_hash(token), p["id"]))
        self.db.commit()
        return 200, {"token": token}

    def report(self, p, body):
        """A report about a public name, for the moderators (admin.py)."""
        target = str(body.get("player", "")).strip()[:40]
        reason = str(body.get("reason", "")).strip()[:200]
        if not target:
            return 400, {"error": "who are you reporting?"}
        if not self.db.execute("SELECT 1 FROM players WHERE display_name=? AND name_hidden=0", (target,)).fetchone():
            return 404, {"error": "no such player"}
        day = self.db.execute("SELECT COUNT(*) FROM reports WHERE reporter=? AND created>?", (p["id"], self.clock() - 86400)).fetchone()[0]
        if day >= REPORTS_PER_DAY:
            return 429, {"error": "that is enough reports for today"}
        self.db.execute("INSERT INTO reports (reporter, target, reason, created) VALUES (?,?,?,?)", (p["id"], target, reason, self.clock()))
        self.db.commit()
        return 200, {"ok": True}

    def export_me(self, p):
        out = {"player": {k: p[k] for k in ("id", "created", "age_group", "display_name", "visibility", "friend_code")}}
        for table in ("crag_attempts", "expedition_runs", "submissions", "follows"):
            out[table] = [dict(r) for r in self.db.execute(f"SELECT * FROM {table} WHERE player_id=?", (p["id"],))]
        out["reports_made"] = [dict(r) for r in self.db.execute("SELECT target, reason, created FROM reports WHERE reporter=?", (p["id"],))]
        return 200, out

    def delete_me(self, p):
        pid = p["id"]
        for table in ("crag_attempts", "expedition_runs", "submissions"):
            self.db.execute(f"DELETE FROM {table} WHERE player_id=?", (pid,))
        self.db.execute("DELETE FROM follows WHERE player_id=? OR friend_id=?", (pid, pid))
        self.db.execute("DELETE FROM reports WHERE reporter=?", (pid,))
        # A first stays a first, with nobody's name on it.
        self.db.execute("UPDATE firsts SET player_id=NULL, display='a deleted account' WHERE player_id=?", (pid,))
        self.db.execute("DELETE FROM players WHERE id=?", (pid,))
        self.db.commit()
        return 204, {}

    def follow(self, p, body):
        if p["age_group"] == "under13":
            return 403, {"error": "under 13: no friends lists"}
        f = self.db.execute("SELECT id, age_group FROM players WHERE friend_code=?", (str(body.get("friendCode", "")).upper(),)).fetchone()
        if not f or f["id"] == p["id"] or f["age_group"] == "under13":
            return 404, {"error": "no such friend code"}
        self.db.execute("INSERT OR IGNORE INTO follows VALUES (?,?)", (p["id"], f["id"]))
        self.db.commit()
        return 200, {"ok": True}

    # --- submissions -----------------------------------------------------

    def submit(self, p, body):
        now = self.clock()
        sid = body.get("id")
        kind = body.get("kind")
        if not isinstance(sid, str) or not 8 <= len(sid) <= 64 or kind not in ("crag", "expedition"):
            return 400, {"ok": False, "reason": "bad submission"}
        if p["banned"]:
            return 403, {"ok": False, "reason": "this account is suspended"}
        # The same submission again (a retry after a lost reply): the same answer.
        old = self.db.execute("SELECT reply FROM submissions WHERE player_id=? AND id=?", (p["id"], sid)).fetchone()
        if old:
            reply = json.loads(old["reply"])
            reply["duplicate"] = True
            return 200, reply
        recent = self.db.execute("SELECT COUNT(*) FROM submissions WHERE player_id=? AND received>?", (p["id"], now - RATE_WINDOW)).fetchone()[0]
        if recent >= RATE_LIMIT:
            return 429, {"ok": False, "retry": True, "reason": "too many at once"}
        client_time = body.get("clientTime")
        if not isinstance(client_time, int) or client_time > now + FUTURE_SLACK:
            reply = {"ok": False, "reason": "the device clock is ahead of the server"}
            return self._log(p, sid, kind, now, reply)
        try:
            if kind == "crag":
                reply = self._crag(p, sid, body.get("payload"), now)
            else:
                reply = self._expedition(p, sid, body.get("payload"), now)
        except validate.Rejected as e:
            reply = {"ok": False, "reason": str(e)}
        return self._log(p, sid, kind, now, reply)

    def _log(self, p, sid, kind, now, reply):
        reply.setdefault("serverTime", now)
        self.db.execute("INSERT INTO submissions VALUES (?,?,?,?,?,?,?)",
                        (p["id"], sid, kind, now, "accepted" if reply.get("ok") else "rejected", reply.get("reason"), json.dumps(reply)))
        self.db.commit()
        return 200, reply

    def _crag(self, p, sid, payload, now):
        a = validate.check_crag(payload)
        board = a["route"]
        if a["route"] == "daily":
            today = time.strftime("%Y-%m-%d", time.gmtime(now))
            earliest = time.strftime("%Y-%m-%d", time.gmtime(now - LATE_DAILY_DAYS * 86400))
            if not earliest <= a["date"] <= today:
                raise validate.Rejected("that daily route is closed")
            board = "daily:" + a["date"]
        earlier = self.db.execute("SELECT COUNT(*) FROM crag_attempts WHERE player_id=? AND board=?", (p["id"], board)).fetchone()[0]
        st = validate.style(a["sent"], a["falls"], earlier, a["beta"])
        self.db.execute("INSERT INTO crag_attempts VALUES (?,?,?,?,?,?,?,?,?)",
                        (p["id"], sid, board, int(a["sent"]), a["seconds"], a["falls"], a["rows"], st, now))
        first = False
        if a["sent"]:
            first = self._claim_first("crag:" + board, p, now)
        self.db.commit()
        reply = {"ok": True, "verified": True, "style": st, "firstVerifiedAscent": first}
        if a["sent"]:
            reply["rank"] = self._rank_of(board, "time", p["id"])
            if a["falls"] == 0:
                reply["cleanRank"] = self._rank_of(board, "clean", p["id"])
        return reply

    def _expedition(self, p, sid, payload, now):
        r = validate.check_expedition(payload)
        self.db.execute("INSERT INTO expedition_runs VALUES (?,?,?,?,?,?,?,?)",
                        (p["id"], sid, r["difficulty"], int(r["assisted"]), r["score"], int(r["complete"]), now, r["points"]))
        first = self._claim_first("expedition:complete", p, now) if r["complete"] else False
        self.db.commit()
        return {"ok": True, "verified": True, "score": r["score"], "points": r["points"], "complete": r["complete"], "firstVerifiedCompletion": first}

    def _claim_first(self, scope, p, now):
        # First by the server's clock: only an empty slot is taken.
        cur = self.db.execute("INSERT OR IGNORE INTO firsts VALUES (?,?,?,?)", (scope, p["id"], self._public_name(p), now))
        return cur.rowcount == 1

    def _public_name(self, p):
        if p["age_group"] == "under13" or p["visibility"] == "private" or not p["display_name"] or p["name_hidden"]:
            return "a climber"
        return p["display_name"]

    # --- boards ----------------------------------------------------------

    def _visible(self, viewer, scope):
        """Player ids whose records this viewer may see on a board."""
        if scope == "friends":
            if viewer is None:
                return None
            ids = [r["friend_id"] for r in self.db.execute("SELECT friend_id FROM follows WHERE player_id=?", (viewer["id"],))]
            ids.append(viewer["id"])
            rows = self.db.execute(f"SELECT id FROM players WHERE id IN ({','.join('?' * len(ids))}) AND age_group!='under13' AND banned=0 AND (visibility!='private' OR id=?)", (*ids, viewer["id"]))
            return {r["id"] for r in rows}
        return {r["id"] for r in self.db.execute("SELECT id FROM players WHERE age_group!='under13' AND visibility='public' AND banned=0")}

    def crag_board(self, board, kind="time", scope="global", viewer=None, limit=50):
        ids = self._visible(viewer, scope)
        if ids is None:
            return []
        clean = " AND falls=0" if kind == "clean" else ""
        rows = self.db.execute(f"SELECT player_id, seconds, received FROM crag_attempts WHERE board=? AND sent=1{clean}", (board,)).fetchall()
        best = {}
        for r in rows:
            if r["player_id"] not in ids:
                continue
            b = best.get(r["player_id"])
            if b is None or (r["seconds"], r["received"]) < (b["seconds"], b["received"]):
                best[r["player_id"]] = r
        entries = sorted(best.values(), key=lambda r: (r["seconds"], r["received"]))
        return self._ranked(entries, "seconds", lower=True)[:limit]

    def expedition_board(self, difficulty, assisted=False, scope="global", viewer=None, limit=50):
        ids = self._visible(viewer, scope)
        if ids is None:
            return []
        # Ranked by leader points (validate.leader_points): completed runs
        # first, then points; ties go to the earlier.
        rows = self.db.execute("SELECT player_id, score, COALESCE(points, score) AS points, complete, received FROM expedition_runs WHERE difficulty=? AND assisted=?", (difficulty, int(assisted))).fetchall()
        best = {}
        for r in rows:
            if r["player_id"] not in ids:
                continue
            key = (-r["complete"], -r["points"], r["received"])
            b = best.get(r["player_id"])
            if b is None or key < (-b["complete"], -b["points"], b["received"]):
                best[r["player_id"]] = r
        entries = sorted(best.values(), key=lambda r: (-r["complete"], -r["points"], r["received"]))
        out = []
        for e in entries:
            better = sum(1 for o in entries if (o["complete"], o["points"]) > (e["complete"], e["points"]))
            out.append({"rank": better + 1, "player": self._name_of(e["player_id"]), "points": e["points"], "score": e["score"], "complete": bool(e["complete"]), "received": e["received"]})
        return out[:limit]

    def _ranked(self, entries, key, lower=True):
        out = []
        for e in entries:
            better = sum(1 for o in entries if (o[key] < e[key] if lower else o[key] > e[key]))
            out.append({"rank": better + 1, "player": self._name_of(e["player_id"]), key: e[key], "received": e["received"]})
        return out

    def _rank_of(self, board, kind, pid):
        for e in self.crag_board(board, kind, "global", None, limit=10 ** 6):
            if e["player"] == self._name_of(pid):
                return e["rank"]
        return None

    def _name_of(self, pid):
        p = self.db.execute("SELECT * FROM players WHERE id=?", (pid,)).fetchone()
        return self._public_name(p) if p else "a deleted account"

    def firsts(self):
        return [dict(r) | {"player_id": None} for r in self.db.execute("SELECT scope, display, received FROM firsts ORDER BY received")]

    def health(self):
        self.db.execute("SELECT 1").fetchone()
        return 200, {"ok": True, "version": VERSION, "time": self.clock()}


def _hash(token):
    return hashlib.sha256(token.encode()).hexdigest()


# --- HTTP ------------------------------------------------------------------------

def _client_address(environ, trust_proxy):
    """The client's address. Behind a proxy, the last X-Forwarded-For entry:
    the one the nearest proxy (Caddy, Fly.io, Render) added. Earlier entries
    come from the client and can be made up."""
    if trust_proxy and environ.get("HTTP_X_FORWARDED_FOR"):
        return environ["HTTP_X_FORWARDED_FOR"].split(",")[-1].strip()
    return environ.get("REMOTE_ADDR", "")


def make_app(service: Service, trust_proxy=False, log=None):
    """The WSGI app. `log`: a function taking one dict per request (None:
    no request log)."""
    def app(environ, start_response):
        t0 = time.monotonic()
        state = {}

        def respond(status, headers):
            state["status"] = int(status.split()[0])
            return start_response(status, headers)
        try:
            with service.lock:
                out = _handle(environ, respond)
        except Exception as e:  # never leak a traceback to a client
            state["error"] = type(e).__name__
            if log:
                log({"event": "error", "error": repr(e)[:300]})
            out = _send(respond, 500, {"error": "server error"})
        if log:
            entry = {"t": int(time.time()), "method": environ.get("REQUEST_METHOD"), "path": environ.get("PATH_INFO", "")[:80],
                     "status": state.get("status"), "ms": round((time.monotonic() - t0) * 1000, 1)}
            if "error" in state:
                entry["error"] = state["error"]
            log(entry)
        return out

    def _handle(environ, start_response):
        method = environ["REQUEST_METHOD"]
        path = environ.get("PATH_INFO", "")
        query = {k: v[0] for k, v in parse_qs(environ.get("QUERY_STRING", "")).items()}
        auth = environ.get("HTTP_AUTHORIZATION", "")
        token = auth[7:] if auth.startswith("Bearer ") else ""
        try:
            length = int(environ.get("CONTENT_LENGTH") or 0)
        except ValueError:
            length = 0
        if length > 256 * 1024:
            return _send(start_response, 413, {"error": "too large"})
        raw = environ["wsgi.input"].read(length) if length else b""
        try:
            body = json.loads(raw) if raw else {}
        except ValueError:
            return _send(start_response, 400, {"error": "not JSON"})
        if not isinstance(body, dict):
            return _send(start_response, 400, {"error": "not an object"})
        me = service.player_for(token)
        parts = [p for p in path.split("/") if p]
        status, out = 404, {"error": "not found"}
        if parts == ["healthz"] and method == "GET":
            status, out = service.health()
        elif parts == ["privacy"] and method == "GET" and service.privacy_page:
            data = service.privacy_page
            start_response("200 OK", [("Content-Type", "text/html; charset=utf-8"), ("Content-Length", str(len(data)))])
            return [data]
        elif parts[:2] == ["v1", "players"] and method == "POST":
            status, out = service.create_player(body, _client_address(environ, trust_proxy))
        elif parts[:2] == ["v1", "leaderboards"] and method == "GET" and len(parts) == 4:
            scope = query.get("scope", "global")
            if scope == "friends" and me is None:
                status, out = 401, {"error": "sign in for friends boards"}
            elif parts[2] == "crag":
                status, out = 200, {"entries": service.crag_board(parts[3], query.get("board", "time"), scope, me)}
            elif parts[2] == "daily":
                status, out = 200, {"entries": service.crag_board("daily:" + parts[3], query.get("board", "time"), scope, me)}
            elif parts[2] == "expedition":
                status, out = 200, {"entries": service.expedition_board(parts[3], query.get("assisted") == "1", scope, me)}
        elif parts == ["v1", "firsts"] and method == "GET":
            status, out = 200, {"firsts": service.firsts()}
        elif me is None and parts[:1] == ["v1"]:
            status, out = 401, {"error": "sign in"}
        elif parts == ["v1", "me"] and method == "GET":
            status, out = service.me(me)
        elif parts == ["v1", "me", "rotate"] and method == "POST":
            status, out = service.rotate(me)
        elif parts == ["v1", "reports"] and method == "POST":
            status, out = service.report(me, body)
        elif parts == ["v1", "me"] and method == "PATCH":
            status, out = service.update_me(me, body)
        elif parts == ["v1", "me"] and method == "DELETE":
            status, out = service.delete_me(me)
        elif parts == ["v1", "me", "export"] and method == "GET":
            status, out = service.export_me(me)
        elif parts == ["v1", "friends"] and method == "POST":
            status, out = service.follow(me, body)
        elif parts == ["v1", "submissions"] and method == "POST":
            status, out = service.submit(me, body)
        return _send(start_response, status, out)
    return app


def _send(start_response, status, out):
    reasons = {200: "OK", 201: "Created", 204: "No Content", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden",
               404: "Not Found", 409: "Conflict", 413: "Payload Too Large", 429: "Too Many Requests", 500: "Internal Server Error"}
    data = b"" if status == 204 else json.dumps(out).encode()
    start_response(f"{status} {reasons.get(status, '')}", [("Content-Type", "application/json"), ("Content-Length", str(len(data)))])
    return [data]


def _json_log(entry):
    sys.stdout.write(json.dumps(entry, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def start_backups(db, out, keep=14, every=86400, log=None):
    """Backs the database up now and then every `every` seconds, in a
    background thread (hosts with one machine and a volume, e.g. Fly.io or
    Render; the compose deploy runs its own backup job instead)."""
    from . import backup

    def loop():
        while True:
            try:
                path = backup.backup(db, out, keep)
                if log:
                    log({"event": "backup", "file": os.path.basename(path)})
                wait = every
            except Exception as e:  # logged and retried, never fatal
                if log:
                    log({"event": "backup_failed", "error": repr(e)[:200]})
                wait = 300
            time.sleep(wait)
    t = threading.Thread(target=loop, daemon=True, name="backups")
    t.start()
    return t


def serve(db, port, bind="", trust_proxy=False, accounts_per_hour=ACCOUNTS_PER_HOUR, privacy_file="", backup_dir=""):
    from socketserver import ThreadingMixIn
    from wsgiref.simple_server import WSGIRequestHandler, WSGIServer, make_server

    class Server(ThreadingMixIn, WSGIServer):
        daemon_threads = True

    class Quiet(WSGIRequestHandler):
        def log_message(self, *args):  # the app logs each request as JSON
            pass

    service = Service(db)
    service.accounts_per_hour = accounts_per_hour
    if privacy_file and os.path.exists(privacy_file):
        with open(privacy_file, "rb") as f:
            service.privacy_page = f.read()
    if backup_dir:
        start_backups(db, backup_dir, int(os.environ.get("RECORDS_BACKUP_KEEP", "14")), log=_json_log)
    _json_log({"event": "start", "version": VERSION, "port": port, "db": os.path.basename(db), "trust_proxy": trust_proxy})
    make_server(bind, port, make_app(service, trust_proxy, _json_log), server_class=Server, handler_class=Quiet).serve_forever()


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=os.environ.get("RECORDS_DB", "records.sqlite"))
    ap.add_argument("--port", type=int, default=int(os.environ.get("RECORDS_PORT", "8080")))
    ap.add_argument("--bind", default=os.environ.get("RECORDS_BIND", ""))
    ap.add_argument("--trust-proxy", action="store_true", default=os.environ.get("RECORDS_TRUST_PROXY", "") == "1")
    args = ap.parse_args()
    load_blocked_words(os.environ.get("RECORDS_BLOCKED_WORDS", ""))
    serve(args.db, args.port, args.bind, args.trust_proxy, int(os.environ.get("RECORDS_ACCOUNTS_PER_HOUR", ACCOUNTS_PER_HOUR)),
          os.environ.get("RECORDS_PRIVACY_FILE", ""), os.environ.get("RECORDS_BACKUP_DIR", ""))
