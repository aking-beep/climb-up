"""Backups of the records database, and getting them back.

A consistent copy, safe while the service runs (SQLite's online backup),
kept with the newest few:

    python3 -m server.records_service.backup --db /data/records.sqlite --out /backups --keep 14

Check a copy (integrity, the tables, how many of each) without changing it:

    python3 -m server.records_service.backup --verify /backups/records-20261016-030000.sqlite

Put a copy back. Stop the service first. The database it replaces is kept
beside it as records.sqlite.before-restore-<time>:

    python3 -m server.records_service.backup --db /data/records.sqlite --restore /backups/records-....sqlite

Rehearse a restore without touching the live database: restore the copy
into a scratch directory, start the service on it, and check it answers
with the same records:

    python3 -m server.records_service.backup --drill /backups/records-....sqlite

The deploy runs a backup daily (deploy/docker-compose.yml; the service's
own RECORDS_BACKUP_DIR on Fly and Render), and
.github/workflows/backup-records.yml copies one off the host every night
and runs the drill on it. A backup on the same disk is not a backup.
"""

import argparse
import glob
import json
import os
import shutil
import sqlite3
import tempfile
import threading
import time
import urllib.request

TABLES = ("players", "submissions", "crag_attempts", "expedition_runs", "firsts", "follows", "reports")


def backup(db, out, keep=14, now=None):
    if not os.path.exists(db):
        raise FileNotFoundError(f"no database at {db}")
    os.makedirs(out, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S", time.gmtime(now if now is not None else time.time()))
    dest = os.path.join(out, f"records-{stamp}.sqlite")
    src = sqlite3.connect(db)
    dst = sqlite3.connect(dest)
    with dst:
        src.backup(dst)
    ok = dst.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    src.close()
    dst.close()
    if not ok:
        os.remove(dest)
        raise RuntimeError("backup failed its integrity check")
    old = sorted(glob.glob(os.path.join(out, "records-*.sqlite")))
    for path in old[:-keep] if keep > 0 else []:
        os.remove(path)
    return dest


def verify(path):
    """{ok, counts} for a backup, opened read-only. Raises ValueError when
    it is not a whole records database."""
    if not os.path.exists(path):
        raise FileNotFoundError(f"no backup at {path}")
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise ValueError("the backup fails its integrity check")
        have = {r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        missing = [t for t in TABLES if t not in have]
        if missing:
            raise ValueError("the backup is missing tables: " + ", ".join(missing))
        counts = {t: db.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0] for t in TABLES}
    except sqlite3.DatabaseError as e:
        raise ValueError(f"not a records database: {e}")
    finally:
        db.close()
    return {"ok": True, "backup": path, "counts": counts}


def restore(src, db, now=None):
    """Replaces the database at `db` with the backup `src` (checked first).
    The service must be stopped. Returns the verify() result of the
    restored database and where the replaced one was kept."""
    verify(src)
    kept = None
    if os.path.exists(db):
        stamp = time.strftime("%Y%m%d-%H%M%S", time.gmtime(now if now is not None else time.time()))
        kept = f"{db}.before-restore-{stamp}"
        shutil.copy2(db, kept)
    # The old write-ahead log belongs to the old database.
    for extra in ("-wal", "-shm"):
        if os.path.exists(db + extra):
            os.remove(db + extra)
    if os.path.exists(db):
        os.remove(db)
    s = sqlite3.connect(f"file:{src}?mode=ro", uri=True)
    d = sqlite3.connect(db)
    with d:
        s.backup(d)
    s.close()
    d.close()
    out = verify(db)
    out["replaced"] = kept
    return out


def drill(src):
    """Restores `src` into a scratch directory, starts the service on it and
    checks it answers with the backup's records. Touches nothing else."""
    from wsgiref.simple_server import make_server, WSGIRequestHandler
    from . import service

    before = verify(src)["counts"]
    with tempfile.TemporaryDirectory() as d:
        db = os.path.join(d, "records.sqlite")
        restore(src, db)
        svc = service.Service(db)

        class Quiet(WSGIRequestHandler):
            def log_message(self, *args):
                pass
        httpd = make_server("127.0.0.1", 0, service.make_app(svc, log=lambda e: None), handler_class=Quiet)
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        try:
            base = f"http://127.0.0.1:{httpd.server_port}"
            health = json.loads(urllib.request.urlopen(base + "/healthz", timeout=10).read())
            firsts = json.loads(urllib.request.urlopen(base + "/v1/firsts", timeout=10).read())
        finally:
            httpd.shutdown()
            httpd.server_close()
        after = {t: svc.db.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0] for t in TABLES}
        svc.db.close()
    if not health.get("ok"):
        raise RuntimeError("the restored service does not answer /healthz")
    if after != before:
        raise RuntimeError(f"the restored database differs from the backup: {before} != {after}")
    if len(firsts.get("firsts", [])) != before["firsts"]:
        raise RuntimeError("the restored service does not serve the backup's firsts")
    return {"ok": True, "backup": src, "counts": after, "health": health}


def main(argv=None):
    ap = argparse.ArgumentParser(description="Back up, check and restore the CLIMB UP records database")
    ap.add_argument("--db", default=os.environ.get("RECORDS_DB", "records.sqlite"))
    ap.add_argument("--out", default=os.environ.get("RECORDS_BACKUPS", "backups"))
    ap.add_argument("--keep", type=int, default=int(os.environ.get("RECORDS_BACKUP_KEEP", "14")))
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--verify", metavar="BACKUP", help="check a backup and print its counts")
    mode.add_argument("--restore", metavar="BACKUP", help="replace --db with this backup (stop the service first)")
    mode.add_argument("--drill", metavar="BACKUP", help="restore into a scratch copy, start the service on it, check it")
    a = ap.parse_args(argv)
    try:
        if a.verify:
            out = verify(a.verify)
        elif a.restore:
            out = restore(a.restore, a.db)
        elif a.drill:
            out = drill(a.drill)
        else:
            print(backup(a.db, a.out, a.keep))
            return 0
    except (OSError, ValueError, RuntimeError) as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        return 1
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
