"""Moderation and operations for the records service, run on the server:

    python3 -m server.records_service.admin --db records.sqlite stats
    python3 -m server.records_service.admin --db records.sqlite reports
    python3 -m server.records_service.admin --db records.sqlite hide-name "Some Name"
    python3 -m server.records_service.admin --db records.sqlite ban "Some Name"
    python3 -m server.records_service.admin --db records.sqlite unban <player id>
    python3 -m server.records_service.admin --db records.sqlite resolve <report id>

A hidden name shows as "a climber" everywhere (and on firsts it already
held) and frees the name; the player can choose another. A banned player's
submissions are refused and their records leave every board; nothing is
deleted, so a ban can be undone. Players are found by display name or id.
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
    a = ap.parse_args(argv)
    svc = Service(a.db)
    out = {"stats": lambda: stats(svc), "reports": lambda: reports(svc, a.all),
           "hide-name": lambda: hide_name(svc, a.who), "ban": lambda: set_ban(svc, a.who, True),
           "unban": lambda: set_ban(svc, a.who, False), "resolve": lambda: resolve(svc, a.report_id)}[a.cmd]()
    print(json.dumps(out, indent=2))
    return 0 if not (isinstance(out, dict) and "error" in out) else 1


if __name__ == "__main__":
    raise SystemExit(main())
