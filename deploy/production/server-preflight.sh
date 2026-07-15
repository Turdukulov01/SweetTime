#!/usr/bin/env bash
set -Eeuo pipefail

# Read-only target audit. This script does not create files, restart services or change firewall.
. /etc/os-release

printf 'os=%s %s\n' "${NAME}" "${VERSION_ID}"
printf 'kernel=%s arch=%s\n' "$(uname -r)" "$(uname -m)"
printf 'user=%s groups=%s\n' "$(id -un)" "$(id -Gn)"
printf 'time=%s\n' "$(date --iso-8601=seconds)"
printf 'cpu_count=%s\n' "$(getconf _NPROCESSORS_ONLN)"
free -h

if sudo -n true 2>/dev/null; then
  sudo_available=1
  printf 'sudo_noninteractive=yes\n'
else
  sudo_available=0
  printf 'sudo_noninteractive=no\n'
fi

printf 'docker_version='
docker version --format '{{.Server.Version}}' 2>/dev/null || printf 'unavailable'
printf '\ncompose_version='
docker compose version --short 2>/dev/null || printf 'unavailable'
printf '\nservices docker=%s nginx=%s caddy=%s\n' \
  "$(systemctl is-active docker 2>/dev/null || true)" \
  "$(systemctl is-active nginx 2>/dev/null || true)" \
  "$(systemctl is-active caddy 2>/dev/null || true)"

printf 'directories:\n'
for path in \
  /srv/sweetime \
  /srv/sweetime/media \
  /srv/sweetime/backups \
  /srv/sweetime/postgres \
  /srv/sweetime/secrets \
  /srv/projects/sweetime; do
  if [[ -e "${path}" ]]; then
    stat -c '%n owner=%U:%G mode=%a type=%F' "${path}"
    if [[ -w "${path}" ]]; then
      printf '%s writable_by_current_user=yes\n' "${path}"
    else
      printf '%s writable_by_current_user=no\n' "${path}"
    fi
  else
    printf '%s missing\n' "${path}"
  fi
done

printf 'disk:\n'
df -h /srv 2>/dev/null || df -h /
printf 'inodes:\n'
df -i /srv 2>/dev/null || df -i /

printf 'containers:\n'
docker ps --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}' 2>/dev/null || true

printf 'listeners:\n'
if ((sudo_available)); then
  sudo -n ss -lntupH
else
  ss -lntuH
fi

printf 'nginx_sites:\n'
if [[ -d /etc/nginx/sites-enabled ]]; then
  find /etc/nginx/sites-enabled -maxdepth 1 -type l \
    -printf '%f -> %l\n' 2>/dev/null || true
fi
if ((sudo_available)) && command -v nginx >/dev/null 2>&1; then
  printf 'nginx_route_summary:\n'
  sudo -n nginx -T 2>/dev/null \
    | sed -n -E '/^[[:space:]]*(listen|server_name|proxy_pass|ssl_certificate)[[:space:]]/p'
fi

printf 'certbot:\n'
if ((sudo_available)) && command -v certbot >/dev/null 2>&1; then
  sudo -n certbot certificates 2>/dev/null | sed -n '1,60p'
else
  printf 'unavailable_or_sudo_denied\n'
fi

printf 'firewall:\n'
if ((sudo_available)) && command -v ufw >/dev/null 2>&1; then
  sudo -n ufw status
else
  printf 'ufw_unavailable_or_sudo_denied\n'
fi
