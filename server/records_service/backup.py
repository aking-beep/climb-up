"""A consistent copy of the records database, safe while the service runs
(SQLite's online backup), kept with the newest few:

    python3 -m server.records_service.backup --db /data/records.sqlite --out /backups --keep 14

The deploy runs it daily (deploy/docker-compose.yml). Copy /backups off the
host too (deploy/README.md): a backup on the same disk is not a backup.
Restore: stop the service, copy a backup over the database, start it.
"""

import argparse
import glob
import os
import sqlite3
import time


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


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=os.environ.get("RECORDS_DB", "records.sqlite"))
    ap.add_argument("--out", default=os.environ.get("RECORDS_BACKUPS", "backups"))
    ap.add_argument("--keep", type=int, default=int(os.environ.get("RECORDS_BACKUP_KEEP", "14")))
    a = ap.parse_args(argv)
    print(backup(a.db, a.out, a.keep))


if __name__ == "__main__":
    main()
