#!/bin/sh
# Starts the records service as the unprivileged 'records' user. Hosts that
# mount the data volume owned by root (Fly.io, Render) get it handed over
# first; then root is dropped for good.
set -e
if [ "$(id -u)" = 0 ]; then
  mkdir -p /data
  chown records:records /data
  [ -n "$RECORDS_BACKUP_DIR" ] && mkdir -p "$RECORDS_BACKUP_DIR" && chown records:records "$RECORDS_BACKUP_DIR"
  exec setpriv --reuid=records --regid=records --init-groups --inh-caps=-all "$@"
fi
exec "$@"
