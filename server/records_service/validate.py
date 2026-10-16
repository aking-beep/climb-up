"""Checks a finished attempt before it can count. The client sends what
happened (an event log), never a score to trust: the server recomputes the
style, the time ranks and the expedition score itself.

These are anti-cheat measures, not proof: a modified client that fakes a
consistent, steady event log for a physically possible climb can still get
through, so the service also refuses a log it has seen before and holds
outlier times for a moderator (service.py). Docs: docs/records-backend.md
(Integrity).
"""

import hashlib
import json
from pathlib import Path

ROUTES = json.loads((Path(__file__).parent / "data" / "routes.json").read_text())

# The game's fastest climbing: CLIMB_UP 34 px/s x aggressive shoes 1.3, at
# 16 px a row, is 2.8 rows/s. Allow 3.5, and a dyno's jump on a catch.
MAX_ROWS_PER_S = 3.5
DYNO_ROWS = 8
CLOCK_SLACK_S = 1.0
# The game logs the height once a second of climbing (CragLevel
# _physics_process), so a real log has no long silences and about one
# sample a second. A log written by hand rarely does.
MAX_GAP_S = 2.5
MISSING_SAMPLES = 2
STYLES = ("onsight", "flash", "redpoint", "falls", "")


class Rejected(Exception):
    """The attempt cannot count; the message says why (shown to the player)."""


def route_for(route: str, date: str):
    if route == "daily":
        r = ROUTES["daily"].get(date)
        if r is None:
            raise Rejected("unknown daily route date")
        return r
    r = ROUTES["routes"].get(route)
    if r is None:
        raise Rejected("unknown route")
    return r


def check_crag(payload: dict) -> dict:
    """Returns the cleaned attempt {route, date, sent, seconds, falls, rows}
    or raises Rejected."""
    if not isinstance(payload, dict):
        raise Rejected("bad payload")
    route = payload.get("route")
    date = payload.get("date") or ""
    if not isinstance(route, str):
        raise Rejected("bad route")
    r = route_for(route, date)
    if payload.get("mapHash") != r["mapHash"]:
        raise Rejected("this route's map does not match the server's (update the game)")
    go = payload.get("go")
    events = payload.get("events")
    if not isinstance(go, dict) or not isinstance(events, list) or not events:
        raise Rejected("missing event log")
    try:
        sent = bool(go["sent"])
        seconds = int(go["seconds"])
        falls = int(go["falls"])
        rows = int(go["rows"])
    except (KeyError, TypeError, ValueError):
        raise Rejected("bad attempt fields")
    if seconds <= 0 or falls < 0 or rows < 0 or rows > r["rows"] + 2:
        raise Rejected("impossible numbers")
    if falls > r["maxFalls"]:
        raise Rejected("more falls than the route allows")

    last_t = -1.0
    clips = []
    fall_events = 0
    catches = []
    high = 0
    high_samples = []
    end = None
    for i, e in enumerate(events):
        if not (isinstance(e, list) and len(e) == 3 and isinstance(e[0], (int, float)) and isinstance(e[1], str)):
            raise Rejected("bad event")
        t, kind, info = float(e[0]), e[1], e[2]
        if t < last_t - 1e-6:
            raise Rejected("events out of order")
        if t > seconds + CLOCK_SLACK_S:
            raise Rejected("event after the end of the attempt")
        last_t = t
        if i == 0 and kind != "tie_in":
            raise Rejected("the log does not start at the tie-in")
        if kind == "clip":
            clips.append(info)
        elif kind == "fall":
            fall_events += 1
        elif kind == "catch":
            catches.append(t)
        elif kind == "h":
            if not isinstance(info, int) or info < high:
                raise Rejected("height went backwards")
            high_samples.append((t, info))
            high = info
        elif kind == "end":
            end = info
    if end is None or events[-1][1] != "end":
        raise Rejected("the log does not end")
    if not isinstance(end, list) or len(end) != 3:
        raise Rejected("bad end")
    if (end[0] == "top") != sent or int(end[1]) != rows or int(end[2]) != falls:
        raise Rejected("the end does not match the attempt")
    if fall_events != falls:
        raise Rejected("falls do not match the log")

    # A steady clock: the end comes at the attempt's time, nothing goes quiet
    # for long, and the height was sampled about once a second.
    end_t = float(events[-1][0])
    if not seconds - CLOCK_SLACK_S <= end_t <= seconds + 1 + CLOCK_SLACK_S:
        raise Rejected("the log's clock does not match the attempt")
    times = [float(e[0]) for e in events]
    if any(b - a > MAX_GAP_S for a, b in zip(times, times[1:])):
        raise Rejected("the log has a gap")
    if len(high_samples) < seconds - MISSING_SAMPLES:
        raise Rejected("the log is missing height samples")

    # Bolts in order, each from about its own height.
    for n, c in enumerate(clips):
        if not (isinstance(c, list) and len(c) == 2 and c[0] == n):
            raise Rejected("bolts clipped out of order")
        if not (r["bolts"][n] - 4 <= int(c[1]) <= r["bolts"][n] + 6):
            raise Rejected("a bolt clipped from the wrong height")
    if len(clips) > len(r["bolts"]):
        raise Rejected("more clips than bolts")

    # Not faster than a climber can climb.
    prev_t, prev_h = 0.0, 0
    for t, h in high_samples:
        allowed = MAX_ROWS_PER_S * max(t - prev_t, 1.0) + (DYNO_ROWS if any(prev_t - 1 <= c <= t + 1 for c in catches) else 0) + 2
        if h - prev_h > allowed:
            raise Rejected("climbed faster than possible")
        prev_t, prev_h = t, h
    if sent:
        if len(clips) != len(r["bolts"]):
            raise Rejected("a send clips every bolt")
        if seconds < r["rows"] / MAX_ROWS_PER_S:
            raise Rejected("faster than the route allows")
    return {"route": route, "date": date, "sent": sent, "seconds": seconds, "falls": falls, "rows": rows,
            "beta": bool(payload.get("beta", False)), "fingerprint": fingerprint(events)}


def fingerprint(events) -> str:
    """The same log twice is one climb submitted twice (or copied from
    someone else): two real climbs never log the same times to 0.01 s."""
    return hashlib.sha256(json.dumps(events, separators=(",", ":")).encode()).hexdigest()


def style(sent: bool, falls: int, earlier_attempts: int, beta: bool) -> str:
    """The style from the server's own count of earlier attempts."""
    if not sent:
        return ""
    if falls > 0:
        return "falls"
    if earlier_attempts == 0:
        return "flash" if beta else "onsight"
    return "redpoint"


# --- Expedition ---------------------------------------------------------------

BUCKETS = ("judgment", "riskManagement", "teamwork", "preparation")
MAX_NOTE_DELTA = 20
MAX_NOTES = 60
DIFFICULTY = {"lemosho": "standard", "machame": "hard", "umbwe": "hardest"}
# Permit days per route (Trek.ROUTES in the game).
PERMIT = {"lemosho": 13, "machame": 9, "umbwe": 8}
LEADER_MAX, LEADER_TEAM, LEADER_MISSING = 130, 10, 8


def js_round(x: float) -> int:
    import math
    return int(math.floor(x + 0.5))


def _bucket(notes, base):
    return max(0, min(100, js_round(base + sum(float(n["delta"]) for n in notes))))


def score(s: dict) -> int:
    """ExpeditionEngine.score's overall, ported (godot/modes/expedition/
    engine/expedition_engine.gd). Kept in step by the shared test vectors."""
    l = s["ledger"]
    judgment = _bucket(l["judgment"], 52)
    risk = _bucket(l["riskManagement"], 50)
    team_core = _bucket(l["teamwork"], 58)
    prep_core = _bucket(l["preparation"], 56)
    teamwork = max(0, min(100, js_round(team_core * 0.7 + s["teamCondition"] * 0.3)))
    preparation = max(0, min(100, js_round(prep_core * 0.65 + s["supplies"] * 0.15 + s["oxygen"] * 0.2)))
    overall = judgment * 0.34 + risk * 0.28 + teamwork * 0.18 + preparation * 0.2
    if s["returnedSafely"]:
        overall += 6
    else:
        overall = min(overall, 40)
    strong = s["summitReached"] and s["returnedSafely"] and judgment >= 68 and s["teamCondition"] >= 35 and s["health"] >= 25
    if strong:
        overall += 12
    if s["summitReached"] and not s["returnedSafely"]:
        overall = min(overall, 36)
    return max(0, min(100, js_round(overall)))


def leader_points(s: dict, route: str, team_home: int) -> int:
    """Records.leader_points, ported: the score, +10 when all four summit and
    come home, -8 per teammate missing on a summit run, and (whole team
    only) 2 per spare permit day up to 10 and 1 per 10 supplies up to 10."""
    sc = score(s)
    summit, home = bool(s["summitReached"]), bool(s["returnedSafely"])
    everyone = summit and home and team_home >= 4
    team = speed = stores = 0
    if everyone:
        team = LEADER_TEAM
    elif summit:
        team = -LEADER_MISSING * (4 - (max(0, min(4, team_home)) if home else 0))
    if everyone:
        left = PERMIT.get(route, 13) * 24.0 - float(s["elapsedHours"])
        speed = js_round(max(0.0, min(5.0, left / 24.0)) * 2.0)
        stores = js_round(max(0.0, min(100.0, float(s["supplies"]))) / 10.0)
    return max(0, min(LEADER_MAX, sc + team + speed + stores))


def check_expedition(payload: dict) -> dict:
    if not isinstance(payload, dict) or not isinstance(payload.get("state"), dict) or not isinstance(payload.get("run"), dict):
        raise Rejected("bad payload")
    s = payload["state"]
    run = payload["run"]
    try:
        for k in ("health", "teamCondition", "supplies", "oxygen"):
            if not (0 <= float(s[k]) <= 100):
                raise Rejected("a stat out of range")
        ledger = s["ledger"]
        for b in BUCKETS:
            notes = ledger[b]
            if not isinstance(notes, list) or len(notes) > MAX_NOTES:
                raise Rejected("bad ledger")
            marks = set()
            for n in notes:
                if abs(float(n["delta"])) > MAX_NOTE_DELTA or n["mark"] in marks:
                    raise Rejected("bad ledger entry")
                marks.add(n["mark"])
        if bool(s["summitReached"]) and float(s["highestAltitude"]) < 5600:
            raise Rejected("a summit below the crater rim")
        server_score = score(s)
    except (KeyError, TypeError, ValueError):
        raise Rejected("bad expedition fields")
    if int(run.get("score", -1)) != server_score:
        raise Rejected("the score does not match the expedition")
    route = payload.get("route", "")
    if route not in DIFFICULTY:
        raise Rejected("unknown expedition route")
    # Who came home is the client's word (it needs a replay to check), but
    # nobody is home from a run that did not come down.
    try:
        team_home = int(run.get("teamHome", 0))
    except (TypeError, ValueError):
        raise Rejected("bad expedition fields")
    if not 0 <= team_home <= 4 or (team_home > 0 and not bool(s["returnedSafely"])):
        raise Rejected("a team that does not add up")
    try:
        points = leader_points(s, route, team_home)
    except (KeyError, TypeError, ValueError):
        raise Rejected("bad expedition fields")
    if "points" in run and int(run["points"]) != points:
        raise Rejected("the leader points do not match the expedition")
    return {"difficulty": DIFFICULTY[route], "assisted": bool(run.get("assisted", False)), "score": server_score,
            "points": points, "complete": bool(s["summitReached"]) and bool(s["returnedSafely"])}
