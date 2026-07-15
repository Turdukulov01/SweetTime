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

## Google Sign-In setup

Google Sign-In is fail-closed: the API returns `503` until its accepted OAuth audience is configured.
Create an Android OAuth client for the application package and signing certificate, plus a Web OAuth
client whose client ID is used as the server audience. Never add a Google client secret to Flutter.

The registered SweetTime clients use:

- package: `kg.sweettime.app`;
- debug SHA-1: `F6:B6:ED:07:AD:1A:D9:C0:74:12:2B:4C:58:08:27:E1:5A:13:C6:35`.
- release/upload SHA-1: `51:DC:A2:E5:1D:37:6E:BB:B1:B7:E8:A8:A8:77:8A:2D:D4:92:16:54`.

The Web backend client ID is
`23205820785-ap4kgng4fef97ie9l69e5erlufjc8v2i.apps.googleusercontent.com`. Android debug/release
client IDs are configured as authorized presenters (`azp`); they are never accepted as the backend
audience. After the first Play upload, add the Play App Signing SHA-1 as another Android OAuth client.

After creating the clients, set the Web client ID in `deploy/production/.env`:

```dotenv
GOOGLE_AUTH_ENABLED=true
GOOGLE_OAUTH_WEB_CLIENT_ID=23205820785-ap4kgng4fef97ie9l69e5erlufjc8v2i.apps.googleusercontent.com
GOOGLE_OAUTH_AUTHORIZED_PARTY_IDS=["23205820785-3qsqi30tcbppsfhqifr92ro3idiqg8kh.apps.googleusercontent.com","23205820785-thvputte60b3ig74n6pek45o0vm8ft29.apps.googleusercontent.com"]
```

Pass that same Web client ID to Flutter at build/run time:

```powershell
flutter run --dart-define=API_BASE=https://lnp-corporation.duckdns.org `
  --dart-define=GOOGLE_WEB_CLIENT_ID=23205820785-ap4kgng4fef97ie9l69e5erlufjc8v2i.apps.googleusercontent.com
```

The app sends the resulting Google ID token to SweetTime over HTTPS. The backend verifies signature,
issuer, expiry and configured audience, then issues its own SweetTime access/refresh tokens. The
Google token is not stored. Until an SMS provider is connected, the required Kyrgyz contact number
remains explicitly unverified and cannot be used as a login factor.

For release signing, keep `android/key.properties` local and ignored by Git. It must contain
`storeFile`, `storePassword`, `keyAlias=upload` and `keyPassword`; the keystore itself also stays
outside the repository. A release build now fails instead of silently falling back to the debug key.

## Host proxy topology

The host nginx terminates TLS for `lnp-corporation.duckdns.org` and proxies to `127.0.0.1:8080`.
The production Compose stack deliberately maps that loopback port to the **container nginx on port
80**, which then routes `/api/`, `/health` and `/ready` to `backend:8000` and serves guarded media.
Keep the existing Compose mapping `${SWEETIME_HTTP_BIND}:${SWEETIME_HTTP_PORT}:80`; do not replace
it with `127.0.0.1:8080:8000`, which would bypass the container nginx policy and healthcheck.

Use `host-nginx.conf.example` as the reviewed host server block. In particular, keep its explicit
`/media/temp/` deny before the direct media alias; otherwise the host alias would bypass the same
protection in the container nginx. Validate every change with `sudo nginx -t` before reload.

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

## Initial rollout on the prepared server

Upload from the repository root without copying local secrets, caches or build artifacts:

```bash
rsync -avz \
  --exclude '.git' \
  --exclude '.dart_tool' \
  --exclude 'build' \
  --exclude '.venv' \
  --exclude 'node_modules' \
  --exclude '.env' \
  --exclude 'android/key.properties' \
  --exclude '*.jks' \
  --exclude '*.keystore' \
  ./ ranex@81.88.192.41:/srv/projects/sweetime/
```

Then prepare and validate the private environment on the server. Generate separate random hex values
for `POSTGRES_PASSWORD` and `JWT_SECRET`; reuse the PostgreSQL value inside `DATABASE_URL`. Hex avoids
URL-encoding ambiguity. Do not paste either value into chat.

```bash
cd /srv/projects/sweetime/deploy/production
cp .env.example .env
chmod 600 .env
openssl rand -hex 32
openssl rand -hex 32
nano .env
docker compose --env-file .env config >/dev/null
docker compose --env-file .env build backend
```

On a fresh empty database, run the one-shot bootstrap above before starting the public-facing services.
Then start the stack and check both the loopback and TLS paths:

```bash
docker compose --env-file .env up -d
docker compose --env-file .env ps
docker compose --env-file .env logs --tail=100 migrate backend nginx
curl -fsS http://127.0.0.1:8080/ready
curl -fsS https://lnp-corporation.duckdns.org/ready
curl -fsS https://lnp-corporation.duckdns.org/api/companies/sweettime/config
```

The domain root may return `404` because SweetTime currently exposes an API/mobile backend, not a web
landing page. `/ready` and the company config endpoint are the deployment smoke tests.

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
