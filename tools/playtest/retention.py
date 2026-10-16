"""The playtest's measures (docs/playtest-plan.md, "Measurements") from the
usage logs testers paste at the end (Settings > Copy my usage log).

Save each tester's paste as its own file (one JSON event a line), named
for the tester, in one folder, then:

    python3 tools/playtest/retention.py logs/
    python3 tools/playtest/retention.py logs/ --testers testers.csv --json report.json

testers.csv (optional) gives each file's UTC offset in hours, so "day 2"
is the tester's own calendar day, and their recruiting group (A, B, C):

    file,utc_offset,group
    ann.jsonl,-5,A

Counts are printed beside every percentage ("12 of 31"). With 30-50
testers the numbers are directional only; a group under 8 testers is not
reported on its own (the plan's rule).
"""

import argparse
import csv
import json
import os
import statistics
import sys
from collections import defaultdict

MIN_GROUP = 8
# Graded routes: anything but the tutorial (First Climb is route id "first-climb").
TUTORIAL_ROUTE = "first-climb"


def read_log(path):
    events = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue   # a torn line from a paste: skip it, keep the rest
            if isinstance(e, dict) and isinstance(e.get("e"), str) and isinstance(e.get("t"), (int, float)):
                e.setdefault("p", {})
                events.append(e)
    events.sort(key=lambda e: e["t"])
    return events


def day_of(t, offset_hours):
    return int((t + offset_hours * 3600) // 86400)


def tester_facts(events, offset=0.0):
    """What one tester did, in the plan's terms."""
    launches = [e for e in events if e["e"] == "game_launched"]
    if not launches:
        return None
    day1 = day_of(launches[0]["t"], offset)
    days = {day_of(e["t"], offset) - day1 + 1 for e in launches}
    by = defaultdict(list)
    for e in events:
        by[e["e"]].append(e)
    started = {e["p"].get("route") for e in by["route_started"]}
    completed = {e["p"].get("route") for e in by["route_completed"]}
    first_send = {}
    tries = defaultdict(int)
    for e in events:
        r = e["p"].get("route")
        if e["e"] == "route_started":
            tries[r] += 1
        elif e["e"] == "route_completed" and r not in first_send:
            first_send[r] = tries[r]
    tut_start = by["tutorial_started"]
    tut_done = by["tutorial_completed"]
    daily_days = {day_of(e["t"], offset) - day1 + 1 for e in by["daily_started"]}
    expeditions = by["expedition_completed"]
    return {
        "days": sorted(days),
        "d1": 2 in days,
        "d7": bool(days & {7, 8}),
        "tutorial_started": bool(tut_start),
        "tutorial_completed": bool(tut_done),
        "tutorial_seconds": (tut_done[0]["t"] - launches[0]["t"]) if tut_done else None,
        "sent_graded": bool(completed - {TUTORIAL_ROUTE, None}),
        "replayed_sent": any(e["p"].get("sent_before") for e in by["route_replayed"]),
        "routes_started": started - {None},
        "routes_completed": completed - {None},
        "tries_to_send": first_send,
        "daily_unlocked": bool(by["daily_started"]),
        "daily_3_of_7": len(daily_days & set(range(1, 8))) >= 3,
        "sessions": [int(e["p"].get("seconds", 0)) for e in by["session_ended"]],
        "expedition_started": bool(by["expedition_started"]),
        "expeditions": [{"returned": bool(e["p"].get("returned")), "summit": bool(e["p"].get("summit"))} for e in expeditions],
        "descents": [bool(e["p"].get("assisted")) for e in by["descent_completed"]],
    }


def ratio(n, d):
    return {"n": n, "of": d, "pct": round(100.0 * n / d, 1) if d else None}


def measures(facts):
    """The plan's table, from a list of tester_facts()."""
    f = [x for x in facts if x]
    total = len(f)
    tut = [x for x in f if x["tutorial_started"]]
    graded = [x for x in f if x["sent_graded"]]
    daily = [x for x in f if x["daily_unlocked"]]
    exp = [x for x in f if x["expedition_started"]]
    finished = [e for x in f for e in x["expeditions"]]
    descents = [d for x in f for d in x["descents"]]
    tut_secs = [x["tutorial_seconds"] for x in f if x["tutorial_seconds"] is not None]
    sessions = [s for x in f for s in x["sessions"]]
    routes = sorted({r for x in f for r in x["routes_started"]})
    per_route = {}
    for r in routes:
        s = [x for x in f if r in x["routes_started"]]
        tries = [x["tries_to_send"][r] for x in f if r in x["tries_to_send"]]
        per_route[r] = {"completion": ratio(sum(1 for x in s if r in x["routes_completed"]), len(s)),
                        "median_attempts_to_send": statistics.median(tries) if tries else None}
    return {
        "testers": total,
        "tutorial_completion": ratio(sum(1 for x in tut if x["tutorial_completed"]), len(tut)),
        "tutorial_median_seconds": statistics.median(tut_secs) if tut_secs else None,
        "voluntary_replay": ratio(sum(1 for x in graded if x["replayed_sent"]), len(graded)),
        "routes": per_route,
        "daily_participation": ratio(sum(1 for x in daily if x["daily_3_of_7"]), len(daily)),
        "day1_retention": ratio(sum(1 for x in f if x["d1"]), total),
        "day7_retention": ratio(sum(1 for x in f if x["d7"]), total),
        "median_session_seconds": statistics.median(sessions) if sessions else None,
        "expedition_completion": ratio(sum(1 for x in exp if x["expeditions"]), len(exp)),
        "expedition_safe_return": ratio(sum(1 for e in finished if e["returned"]), len(finished)),
        "retreat_rate": ratio(sum(1 for e in finished if not e["summit"]), len(finished)),
        "descent_help_rate": ratio(sum(1 for d in descents if d), len(descents)),
    }


TARGETS = {"tutorial_completion": 85, "voluntary_replay": 40, "daily_participation": 30}
BENCHMARKS = {"day1_retention": "35-40%", "day7_retention": "10-15%"}


def report(path, testers_csv=None):
    meta = {}
    if testers_csv:
        with open(testers_csv, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                meta[row["file"].strip()] = {"offset": float(row.get("utc_offset") or 0), "group": (row.get("group") or "").strip()}
    facts, groups, skipped = [], defaultdict(list), []
    for name in sorted(os.listdir(path)):
        full = os.path.join(path, name)
        if not os.path.isfile(full) or name.startswith("."):
            continue
        m = meta.get(name, {"offset": 0.0, "group": ""})
        x = tester_facts(read_log(full), m["offset"])
        if x is None:
            skipped.append(name)
            continue
        facts.append(x)
        if m["group"]:
            groups[m["group"]].append(x)
    out = {"all": measures(facts), "groups": {}, "skipped": skipped}
    for g, xs in sorted(groups.items()):
        out["groups"][g] = measures(xs) if len(xs) >= MIN_GROUP else {"testers": len(xs), "note": f"fewer than {MIN_GROUP}: not reported alone"}
    return out


def _fmt(r):
    if not isinstance(r, dict) or "of" not in r:
        return "-" if r is None else str(r)
    return f"{r['n']} of {r['of']}" + (f" ({r['pct']}%)" if r["pct"] is not None else "")


def print_report(out, file=sys.stdout):
    m = out["all"]
    w = lambda s: print(s, file=file)
    w(f"CLIMB UP playtest: {m['testers']} testers" + (f" (skipped, no launch: {', '.join(out['skipped'])})" if out["skipped"] else ""))
    for key, label in (("tutorial_completion", "Tutorial completion"), ("voluntary_replay", "Voluntary route replay"),
                       ("daily_participation", "Daily on 3 of days 1-7"), ("day1_retention", "Day 1 retention"),
                       ("day7_retention", "Day 7 retention"), ("expedition_completion", "Expedition completion"),
                       ("expedition_safe_return", "Expedition safe return"), ("retreat_rate", "Retreat rate"),
                       ("descent_help_rate", "Descent help rate")):
        note = f"  target >= {TARGETS[key]}%" if key in TARGETS else (f"  benchmark {BENCHMARKS[key]}" if key in BENCHMARKS else "")
        w(f"  {label:28} {_fmt(m[key])}{note}")
    w(f"  {'Tutorial median time':28} {_fmt(m['tutorial_median_seconds'])} s  target <= 300 s")
    w(f"  {'Median session':28} {_fmt(m['median_session_seconds'])} s")
    w("  Routes (completion; median attempts to first send):")
    for r, v in m["routes"].items():
        w(f"    {r:24} {_fmt(v['completion'])}; {_fmt(v['median_attempts_to_send'])}")
    for g, v in out["groups"].items():
        w(f"  Group {g}: " + (v["note"] if "note" in v else f"{v['testers']} testers, D1 {_fmt(v['day1_retention'])}, D7 {_fmt(v['day7_retention'])}"))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("logs", help="a folder with one pasted usage log per tester")
    ap.add_argument("--testers", help="testers.csv: file,utc_offset,group")
    ap.add_argument("--json", help="also write the full report here")
    a = ap.parse_args(argv)
    out = report(a.logs, a.testers)
    print_report(out)
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(out, f, indent=2, default=list)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
