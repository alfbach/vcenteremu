#!/usr/bin/env bash
set -euo pipefail

TLS_DIR="/etc/vcenteremu/tls"
ENV_DIR="/etc/vcenteremu"
ENV_FILE="${ENV_DIR}/vcenteremu.env"
NGINX_CONF="/etc/nginx/conf.d/vcenteremu.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_NAME="${1:-vcenteremu.local}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Bitte als root ausführen (sudo)."
  exit 1
fi

echo "Installiere nginx ..."
dnf install -y nginx openssl

bash "${SCRIPT_DIR}/generate-tls-cert.sh" "${SERVER_NAME}"

sed "s/vcenteremu.local/${SERVER_NAME}/g" "${SCRIPT_DIR}/nginx/vcenteremu.conf" > "${NGINX_CONF}"

mkdir -p "${ENV_DIR}"
touch "${ENV_FILE}"

set_env() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "${ENV_FILE}"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${ENV_FILE}"
  else
    echo "${key}=${value}" >> "${ENV_FILE}"
  fi
}

set_env "VCENTEREMU_HOST" "127.0.0.1"
set_env "VCENTEREMU_PORT" "8080"
set_env "VCENTEREMU_VCENTER_NAME" "${SERVER_NAME}"
chmod 640 "${ENV_FILE}"

systemctl enable nginx
systemctl restart nginx
systemctl restart vcenteremu 2>/dev/null || true

if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-service=https
  firewall-cmd --permanent --add-service=http
  firewall-cmd --reload
fi

echo ""
echo "TLS/nginx eingerichtet."
echo "  HTTPS: https://${SERVER_NAME}/"
echo "  API:   https://${SERVER_NAME}/rest/"
echo ""
echo "Hinweis: Selbstsigniertes Zertifikat — Clients mit curl -k oder CA importieren."
