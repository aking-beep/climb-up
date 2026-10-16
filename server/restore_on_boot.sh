#!/bin/sh
# Restores the records database from a backup left at $RECORDS_RESTORE_FILE
# (default /data/restore.sqlite) before the service starts. This is how a
# host with no "stopped" state restores: on Fly, upload the backup there
# with `fly ssh sftp`, then `fly machine restart`. A good backup is restored
# (the old database is kept as records.sqlite.before-restore-<time>) and the
# file renamed .done; a bad one is renamed .failed and the old database is
# kept. Either way the service then starts. server/deploy/README.md, Restore.
RESTORE="${RECORDS_RESTORE_FILE:-/data/restore.sqlite}"
DB="${RECORDS_DB:-/data/records.sqlite}"
[ -f "$RESTORE" ] || exit 0
if python3 -m server.records_service.backup --db "$DB" --restore "$RESTORE"; then
  mv "$RESTORE" "$RESTORE.done"
  echo '{"event":"restored"}'
else
  mv "$RESTORE" "$RESTORE.failed"
  echo '{"event":"restore_failed"}'
fi
exit 0
