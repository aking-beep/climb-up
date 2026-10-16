#!/bin/sh
# Starts the records service as the unprivileged 'records' user. Hosts that
# mount the data volume owned by root (Fly.io, Render) get it handed over
# first; then root is dropped for good. A backup waiting at
# /data/restore.sqlite is restored before anything else.
set -e
# Only the service itself restores (not the compose backup job sharing the
# volume).
case "$*" in
  *records_service.service*) sh /app/restore_on_boot.sh ;;
esac
if [ "$(id -u)" = 0 ]; then
  mkdir -p /data
  chown -R records:records /data
  [ -n "$RECORDS_BACKUP_DIR" ] && mkdir -p "$RECORDS_BACKUP_DIR" && chown records:records "$RECORDS_BACKUP_DIR"
  exec setpriv --reuid=records --regid=records --init-groups --inh-caps=-all "$@"
fi
exec "$@"
