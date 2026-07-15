#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
compose_file="${COMPOSE_FILE:-${script_dir}/docker-compose.yml}"
env_file="${ENV_FILE:-${script_dir}/.env}"
backup_root="${BACKUP_ROOT:-/srv/sweetime/backups/snapshots}"
media_root="${MEDIA_ROOT:-/srv/sweetime/media}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
partial="${backup_root}/.${timestamp}.partial"
snapshot="${backup_root}/${timestamp}"

[[ -f "${env_file}" ]] || {
  echo "Missing production env file: ${env_file}" >&2
  exit 1
}
[[ -d "${media_root}" ]] || {
  echo "Missing media directory: ${media_root}" >&2
  exit 1
}

compose=(docker compose --env-file "${env_file}" -f "${compose_file}")
backend_was_running="$("${compose[@]}" ps --status running -q backend)"
nginx_was_running="$("${compose[@]}" ps --status running -q nginx)"
resumed=0

resume_services() {
  if [[ "${resumed}" == 1 ]]; then
    return
  fi
  resumed=1
  local services=()
  [[ -n "${backend_was_running}" ]] && services+=(backend)
  [[ -n "${nginx_was_running}" ]] && services+=(nginx)
  if ((${#services[@]})); then
    "${compose[@]}" up -d "${services[@]}"
  fi
}

cleanup() {
  local exit_code=$?
  resume_services || true
  if [[ -d "${partial}" ]]; then
    rm -rf -- "${partial}"
  fi
  exit "${exit_code}"
}
trap cleanup EXIT INT TERM

[[ ! -e "${snapshot}" && ! -e "${partial}" ]] || {
  echo "Backup snapshot already exists: ${timestamp}" >&2
  exit 1
}

mkdir -p -- "${backup_root}" "${partial}"

# A short write-maintenance window keeps database rows and media files aligned.
"${compose[@]}" stop nginx backend

"${compose[@]}" exec -T postgres sh -c \
  'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom --compress=9' \
  >"${partial}/database.dump"

alembic_version="$("${compose[@]}" exec -T postgres sh -c \
  'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select version_num from alembic_version limit 1"')"

tar -C "${media_root}" -czf "${partial}/media.tar.gz" .
media_files="$(find "${media_root}" -type f -print | wc -l | tr -d ' ')"

cat >"${partial}/metadata.env" <<EOF
CREATED_AT=${timestamp}
ALEMBIC_VERSION=${alembic_version}
MEDIA_FILE_COUNT=${media_files}
EOF

(
  cd -- "${partial}"
  sha256sum database.dump media.tar.gz metadata.env >SHA256SUMS
  sha256sum -c SHA256SUMS
  tar -tzf media.tar.gz >/dev/null
)
"${compose[@]}" exec -T postgres pg_restore --list <"${partial}/database.dump" >/dev/null

mv -- "${partial}" "${snapshot}"
printf '%s\n' "${timestamp}" >"${backup_root}/LATEST.tmp"
mv -- "${backup_root}/LATEST.tmp" "${backup_root}/LATEST"
resume_services
trap - EXIT INT TERM

echo "Created verified local snapshot: ${snapshot}"
echo "This is not off-host protection. Copy it with copy-backup-offsite.sh."
