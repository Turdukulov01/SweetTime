# SweetTime production deployment

The Compose stack is intentionally bound to `127.0.0.1:8080`. Put it behind the host's existing
TLS reverse proxy; do not publish the container nginx directly on an Internet-facing cleartext port.

Before copying or starting anything, run the read-only target audit (SSH may prompt locally for the
server password; do not paste that password into chat or commit it):

```bash
ssh ranex@81.88.192.41 'bash -s' < server-preflight.sh | tee server-preflight.out
```

From Windows PowerShell, use the pipeline form instead of `<` redirection:

```powershell
Get-Content -Raw .\server-preflight.sh | ssh ranex@81.88.192.41 "bash -s"
```

Review the output for existing proxy/ports, Docker access, exact UID/GID, writable directories, disk
and inode capacity. The script makes no server changes and does not print container environments.

## Required preflight

1. Copy `.env.example` to `.env` on the server and replace every placeholder. Never commit `.env`.
2. Pre-create `/srv/sweetime/postgres`, `/srv/sweetime/media` and `/srv/sweetime/backups/snapshots`
   with the UID/GID declared in `.env`; verify free bytes and inodes.
3. Provide a real company/first-owner bootstrap before public traffic. Production deliberately uses
   `SEED_MODE=none` and `OTP_MODE=disabled`; known demo credentials are never created.
4. Configure the outer reverse proxy and TLS before exposing auth, orders, or media.

## One-shot production bootstrap

After migrations and before public traffic, create a root-readable password file outside the repo:

```bash
sudo install -d -m 700 /srv/sweetime/secrets
openssl rand -base64 36 | sudo tee /srv/sweetime/secrets/bootstrap-owner-password >/dev/null
sudo chmod 600 /srv/sweetime/secrets/bootstrap-owner-password
```

Run the explicit overlay once:

```bash
BOOTSTRAP_OWNER_EMAIL=owner@example.com \
BOOTSTRAP_OWNER_NAME='Real Owner Name' \
BOOTSTRAP_OWNER_PASSWORD_FILE=/srv/sweetime/secrets/bootstrap-owner-password \
docker compose --env-file .env \
  -f docker-compose.yml -f docker-compose.bootstrap.yml \
  run --rm bootstrap
```

It creates only company `sweettime`, its branches/catalog/news/promotions and one owner. It creates no
CoffeeGo tenant, demo customer, orders, or known `demo` password, and refuses to run when any company
already exists. Test staff login, store the credential in the approved password manager, then securely
remove the bootstrap password file.

## Backup lifecycle

`backup-production.sh` stops backend writes briefly, creates a versioned PostgreSQL custom dump and
media archive, records Alembic/media metadata, verifies both archives and checksums, then resumes only
the application services that were running. The local snapshot is still on the same physical host.

Copy every accepted snapshot to an independently administered host or storage account:

```bash
OFFSITE_RSYNC_TARGET=backup@backup-host:/srv/backups/sweetime \
  ./copy-backup-offsite.sh
```

Never add `--delete`: versioned backups must survive accidental source deletion. Retention and remote
encryption are policies of the off-host target and must be documented before S7.

Run a non-destructive restore drill after initial setup and regularly thereafter:

```bash
./restore-drill.sh
```

The drill restores into a disposable PostgreSQL container, compares Alembic head, extracts media to a
temporary directory and validates file counts. It never connects to or overwrites production.
