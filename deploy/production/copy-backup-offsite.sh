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
target="${OFFSITE_RSYNC_TARGET:-}"

[[ -n "${target}" ]] || {
  echo "Set OFFSITE_RSYNC_TARGET, for example backup@host:/srv/backups/sweetime" >&2
  exit 1
}
[[ -d "${snapshot}" && -f "${snapshot}/SHA256SUMS" ]] || {
  echo "Invalid snapshot directory: ${snapshot}" >&2
  exit 1
}

(
  cd -- "${snapshot}"
  sha256sum -c SHA256SUMS
)

snapshot_name="$(basename -- "$(readlink -f -- "${snapshot}")")"
rsync -a --checksum --protect-args \
  "$(readlink -f -- "${snapshot}")/" "${target%/}/${snapshot_name}/"

echo "Copied immutable snapshot ${snapshot_name} to off-host target."
