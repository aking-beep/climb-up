# Deploying the records service (closed beta)

Three ways to run it. All use the same image (`server/Dockerfile`), which:
- runs as an unprivileged user;
- serves the privacy policy at `/privacy`;
- answers `/healthz`.

| Option | Cost (approx.) | HTTPS | Backups | You need |
| --- | --- | --- | --- | --- |
| **Fly.io** (`fly.toml`) | about $2–5/month (shared-cpu-1x, 256 MB, 1 GB volume) | Fly | Fly's daily volume snapshots, plus the service's own daily backups in `/data/backups` | A Fly account and `flyctl` |
| **Render** (`/render.yaml`) | about $7–8/month (Starter plus a 1 GB disk) | Render | Render's daily disk snapshots, plus the service's own backups | A Render account |
| **Your own VM** (`docker-compose.yml`) | about $5/month | Caddy, Let's Encrypt | A daily backup job | A VM, a domain, an off-host backup copy |

Prices are estimates; check the provider's current pricing.

### Fly.io

From the repository root, with `flyctl` signed in:

```sh
fly launch --no-deploy --copy-config --config server/deploy/fly.toml --name climbup-records-<you>
fly volumes create records_data --size 1 --region iad --config server/deploy/fly.toml
fly deploy --config server/deploy/fly.toml --dockerfile server/Dockerfile
curl https://climbup-records-<you>.fly.dev/healthz
```

Optional: `fly certs add records.<your-domain>` and a CNAME record for
your own domain.

### Render

New → Blueprint, then pick this repository. `render.yaml` at the
repository root defines the service and its disk. After the first deploy,
the service is at `https://climbup-records.onrender.com` or similar.

### Your own VM (Docker Compose with Caddy)

This directory holds a complete setup:

| Piece | What it does |
| --- | --- |
| `../Dockerfile` | The service image. Standard library only. Drops to a non-root user after taking ownership of the data volume (`../entrypoint.sh`). Has a health check |
| `fly.toml`, `../../render.yaml` | The Fly.io and Render setups above |
| `docker-compose.yml` | The service, Caddy (HTTPS), and a daily backup job |
| `Caddyfile` | TLS with automatic Let's Encrypt certificates, HSTS, a 256 KB request limit |
| `blocked-words.txt` | Extra words public names may not contain |
| `site/privacy.html` | The privacy policy, served at `https://$RECORDS_DOMAIN/privacy`. Fill in the publisher, contact and date before launch |

#### What you need before you start

1. **A host.** Any VM with Docker and Docker Compose and ports 80 and 443
   open. 1 vCPU and 512 MB RAM is plenty for a beta.
2. **A domain**, for example `records.example.com`, with an A/AAAA record
   pointing at the host. Caddy needs it to get a certificate.
3. **An off-host copy of the backups.** For example a nightly `rclone` or
   `rsync` of the `records-backups` volume to object storage.

#### Start it

```sh
git clone https://github.com/aking-beep/climb-up && cd climb-up/server/deploy
export RECORDS_DOMAIN=records.example.com
docker compose up -d --build
curl https://$RECORDS_DOMAIN/healthz    # {"ok": true, "version": "1.1.0", ...}
```

The database lives in the `records-data` volume
(`/data/records.sqlite`). It survives restarts, upgrades and rebuilds.

## Point the game at it

The Android build reads the endpoint from `project.godot`:

```ini
[climb_up]
records/endpoint="https://records.example.com"
records/privacy_url="https://records.example.com/privacy"
```

Then rebuild the release (`tools/godot/export.sh android-release`). With
no endpoint set, the game keeps every record on the device and the
Global and Friends tabs say they are not connected.

## Daily routes

The server checks Daily Crag goes against the route data the game itself
exports (`server/records_service/data/routes.json`). The file in the repo
covers 200 days from 2026-10-12, which is long enough for the beta.
Before that runs out, or with each release, regenerate it and redeploy:

```sh
godot --headless --path godot res://tests/export_routes.tscn -- \
  out=$PWD/server/records_service/data/routes.json from=$(date -u +%F) days=200
docker compose up -d --build
```

## Operations

- **Logs.** One JSON line per request: time, method, path, status, ms.
  There are no tokens and no client addresses. Caddy writes no access
  log. Errors are logged as `{"event": "error"}`.
  View them with `docker compose logs -f records`. Logs rotate at
  5 × 20 MB.
- **Health.** `GET /healthz` checks the database. Docker restarts the
  container if it fails three times in a row. Point an uptime monitor at
  `https://$RECORDS_DOMAIN/healthz`.
- **Backups.** The `backup` service takes a consistent copy every 24
  hours. It uses SQLite's online backup and checks integrity, and keeps
  the newest 14. A failed backup logs `backup_failed` and is retried in
  5 minutes.
- **Restore.**
  1. `docker compose stop records`
  2. Copy a backup over `/data/records.sqlite` in the `records-data`
     volume, and remove any `records.sqlite-wal` and `-shm` files there.
  3. `docker compose start records`

## Moderation

Reports from the game's records screen ("Report name") are kept for
moderators. Work through them on the host:

```sh
A="docker compose exec records python3 -m server.records_service.admin"
$A stats                       # players, attempts, open reports
$A reports                     # open reports, with how often each name was reported
$A hide-name "Some Name"       # shows as "a climber" everywhere; the name is freed
$A ban "Some Name"             # submissions refused, off every board (reversible)
$A unban <player id>
$A resolve <report id>         # dismiss a report
```

Check the reports at least every few days during the beta. Add words to
`blocked-words.txt` and restart the service (`docker compose restart
records`).

## Limits for this beta

- **One instance.** SQLite with one writer. This is fine for thousands of
  players. Move to Postgres before running more than one instance.
- **The account throttle is in memory.** 30 new accounts per address per
  hour (`RECORDS_ACCOUNTS_PER_HOUR`). It resets when the service restarts.
- **Anti-cheat stops casual cheating only.** See
  `docs/records-backend.md` §3.
