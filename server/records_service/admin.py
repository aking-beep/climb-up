"""Moderation and operations for the records service, run on the server:

    python3 -m server.records_service.admin --db records.sqlite stats
    python3 -m server.records_service.admin --db records.sqlite reports
    python3 -m server.records_service.admin --db records.sqlite hide-name "Some Name"
    python3 -m server.records_service.admin --db records.sqlite ban "Some Name"
    python3 -m server.records_service.admin --db records.sqlite unban <player id>
    python3 -m server.records_service.admin --db records.sqlite resolve <report id>
    python3 -m server.records_service.admin --db records.sqlite review
    python3 -m server.records_service.admin --db records.sqlite approve crag:<n>
    python3 -m server.records_service.admin --db records.sqlite refuse crag:<n>

A hidden name shows as "a climber" everywhere (and on firsts it already
held) and frees the name; the player can choose another. A banned player's
submissions are refused and their records leave every board; nothing is
deleted, so a ban can be undone. Players are found by display name or id.

`review` lists records held as outliers (service.REVIEW_*): a send far
faster than the board's best, or an expedition far above it. Look at the
player's other attempts (`--db ... review` shows them) and approve one to
put it on the boards, or refuse it to keep it off for good. An approved
send claims its route's first only if nobody has it yet.
"""

import argparse
import json
import os

from .service import Service


def _find(svc, who):
    return svc.db.execute("SELECT * FROM players WHERE id=? OR display_name=?", (who, who)).fetchone()


def stats(svc):
    q = lambda sql: svc.db.execute(sql).fetchone()[0]
    return {"players": q("SELECT COUNT(*) FROM players"),
            "banned": q("SELECT COUNT(*) FROM players WHERE banned=1"),
            "hiddenNames": q("SELECT COUNT(*) FROM players WHERE name_hidden=1"),
            "cragAttempts": q("SELECT COUNT(*) FROM crag_attempts"),
            "expeditionRuns": q("SELECT COUNT(*) FROM expedition_runs"),
            "rejectedSubmissions": q("SELECT COUNT(*) FROM submissions WHERE status='rejected'"),
            "heldForReview": q("SELECT (SELECT COUNT(*) FROM crag_attempts WHERE held=1) + (SELECT COUNT(*) FROM expedition_runs WHERE held=1)"),
            "openReports": q("SELECT COUNT(*) FROM reports WHERE resolved=0")}


def reports(svc, include_resolved=False):
    where = "" if include_resolved else "WHERE resolved=0"
    rows = svc.db.execute(f"SELECT id, target, reason, created, resolved, (SELECT COUNT(*) FROM reports r2 WHERE r2.target=reports.target) AS times FROM reports {where} ORDER BY created")
    return [dict(r) for r in rows]


def hide_name(svc, who):
    p = _find(svc, who)
    if not p:
        return {"error": "no such player"}
    # Free the name and keep it off every board and first it holds.
    svc.db.execute("UPDATE players SET name_hidden=1, display_name=NULL, name_key=NULL WHERE id=?", (p["id"],))
    svc.db.execute("UPDATE firsts SET display='a climber' WHERE player_id=?", (p["id"],))
    svc.db.execute("UPDATE reports SET resolved=1 WHERE target=?", (p["display_name"],))
    svc.db.commit()
    return {"ok": True, "player": p["id"]}


def set_ban(svc, who, banned):
    p = _find(svc, who)
    if not p:
        return {"error": "no such player"}
    svc.db.execute("UPDATE players SET banned=? WHERE id=?", (int(banned), p["id"]))
    svc.db.commit()
    return {"ok": True, "player": p["id"], "banned": banned}


TABLES = {"crag": "crag_attempts", "expedition": "expedition_runs"}


def review(svc):
    out = []
    for r in svc.db.execute("SELECT rowid, * FROM crag_attempts WHERE held=1 ORDER BY received"):
        others = svc.db.execute("SELECT COUNT(*), MIN(seconds) FROM crag_attempts WHERE player_id=? AND board=? AND held=0 AND sent=1", (r["player_id"], r["board"])).fetchone()
        best = svc.db.execute("SELECT MIN(seconds) FROM crag_attempts WHERE board=? AND held=0 AND sent=1", (r["board"],)).fetchone()[0]
        out.append({"ref": f"crag:{r['rowid']}", "player": svc._name_of(r["player_id"]), "playerId": r["player_id"], "board": r["board"],
                    "seconds": r["seconds"], "boardBest": best, "theirOtherSends": others[0], "theirBestOtherwise": others[1],
                    "falls": r["falls"], "received": r["received"]})
    for r in svc.db.execute("SELECT rowid, * FROM expedition_runs WHERE held=1 ORDER BY received"):
        best = svc.db.execute("SELECT MAX(COALESCE(points, score)) FROM expedition_runs WHERE difficulty=? AND assisted=? AND held=0 AND complete=1", (r["difficulty"], r["assisted"])).fetchone()[0]
        out.append({"ref": f"expedition:{r['rowid']}", "player": svc._name_of(r["player_id"]), "playerId": r["player_id"], "difficulty": r["difficulty"],
                    "points": r["points"], "boardBest": best, "received": r["received"]})
    return out


def decide(svc, ref, approve):
    kind, _, n = ref.partition(":")
    if kind not in TABLES or not n.isdigit():
        return {"error": "a ref looks like crag:12 or expedition:3 (from review)"}
    r = svc.db.execute(f"SELECT rowid, * FROM {TABLES[kind]} WHERE rowid=? AND held=1", (int(n),)).fetchone()
    if not r:
        return {"error": "nothing held with that ref"}
    svc.db.execute(f"UPDATE {TABLES[kind]} SET held=? WHERE rowid=?", (0 if approve else 2, int(n)))
    first = False
    if approve:
        p = svc.db.execute("SELECT * FROM players WHERE id=?", (r["player_id"],)).fetchone()
        if kind == "crag" and r["sent"]:
            first = svc._claim_first("crag:" + r["board"], p, r["received"])
        elif kind == "expedition" and r["complete"]:
            first = svc._claim_first("expedition:complete", p, r["received"])
    svc.db.commit()
    return {"ok": True, "ref": ref, "approved": approve, "first": first}


def resolve(svc, report_id):
    n = svc.db.execute("UPDATE reports SET resolved=1 WHERE id=?", (int(report_id),)).rowcount
    svc.db.commit()
    return {"ok": n == 1}


def main(argv=None):
    ap = argparse.ArgumentParser(description="CLIMB UP records moderation")
    ap.add_argument("--db", default=os.environ.get("RECORDS_DB", "records.sqlite"))
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("stats")
    r = sub.add_parser("reports")
    r.add_argument("--all", action="store_true")
    for name in ("hide-name", "ban", "unban"):
        sub.add_parser(name).add_argument("who")
    sub.add_parser("resolve").add_argument("report_id")
    sub.add_parser("review")
    for name in ("approve", "refuse"):
        sub.add_parser(name).add_argument("ref")
    a = ap.parse_args(argv)
    svc = Service(a.db)
    out = {"stats": lambda: stats(svc), "reports": lambda: reports(svc, a.all),
           "hide-name": lambda: hide_name(svc, a.who), "ban": lambda: set_ban(svc, a.who, True),
           "unban": lambda: set_ban(svc, a.who, False), "resolve": lambda: resolve(svc, a.report_id),
           "review": lambda: review(svc), "approve": lambda: decide(svc, a.ref, True),
           "refuse": lambda: decide(svc, a.ref, False)}[a.cmd]()
    print(json.dumps(out, indent=2))
    return 0 if not (isinstance(out, dict) and "error" in out) else 1


if __name__ == "__main__":
    raise SystemExit(main())
