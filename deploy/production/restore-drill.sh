#!/usr/bin/env bash
set -Eeuo pipefail

backup_root="${BACKUP_ROOT:-/srv/sweetime/backups/snapshots}"
if (($#)); then
  snapshot="$1"
else
  [[ -f "${backup_root}/LATEST" ]] || {
    echo "Missing ${backup_root}/LATEST" >&2
    exit 1
  }
  snapshot="${backup_root}/$(<"${backup_root}/LATEST")"
fi
snapshot="$(readlink -f -- "${snapshot}")"
container="sweettime-restore-drill-$$"
temp_root="$(mktemp -d)"

cleanup() {
  docker rm -f "${container}" >/dev/null 2>&1 || true
  rm -rf -- "${temp_root}"
}
trap cleanup EXIT INT TERM

[[ -d "${snapshot}" ]] || {
  echo "Snapshot does not exist: ${snapshot}" >&2
  exit 1
}
for required in database.dump media.tar.gz metadata.env SHA256SUMS; do
  [[ -f "${snapshot}/${required}" ]] || {
    echo "Snapshot is missing ${required}" >&2
    exit 1
  }
done

(
  cd -- "${snapshot}"
  sha256sum -c SHA256SUMS
  tar -tzf media.tar.gz >/dev/null
)

expected_alembic="$(sed -n 's/^ALEMBIC_VERSION=//p' "${snapshot}/metadata.env")"
expected_media_files="$(sed -n 's/^MEDIA_FILE_COUNT=//p' "${snapshot}/metadata.env")"
[[ -n "${expected_alembic}" && "${expected_media_files}" =~ ^[0-9]+$ ]] || {
  echo "Invalid snapshot metadata" >&2
  exit 1
}

docker run -d --name "${container}" \
  -e POSTGRES_DB=sweettime_restore \
  -e POSTGRES_USER=sweettime_restore \
  -e POSTGRES_PASSWORD=restore-drill-only \
  postgres:16-alpine >/dev/null

ready=0
for _ in {1..30}; do
  if docker exec "${container}" \
    pg_isready -U sweettime_restore -d sweettime_restore >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
[[ "${ready}" == 1 ]] || {
  echo "Restore-drill PostgreSQL did not become ready" >&2
  exit 1
}

docker cp "${snapshot}/database.dump" "${container}:/tmp/database.dump"
docker exec "${container}" pg_restore \
  --exit-on-error --no-owner --no-privileges \
  -U sweettime_restore -d sweettime_restore /tmp/database.dump

actual_alembic="$(docker exec "${container}" psql \
  -U sweettime_restore -d sweettime_restore -tAc \
  'select version_num from alembic_version limit 1')"
[[ "${actual_alembic}" == "${expected_alembic}" ]] || {
  echo "Alembic mismatch: expected ${expected_alembic}, got ${actual_alembic}" >&2
  exit 1
}

mkdir -p -- "${temp_root}/media"
tar -C "${temp_root}/media" -xzf "${snapshot}/media.tar.gz"
actual_media_files="$(find "${temp_root}/media" -type f -print | wc -l | tr -d ' ')"
[[ "${actual_media_files}" == "${expected_media_files}" ]] || {
  echo "Media count mismatch: expected ${expected_media_files}, got ${actual_media_files}" >&2
  exit 1
}

echo "Restore drill passed: alembic=${actual_alembic}, media_files=${actual_media_files}"
