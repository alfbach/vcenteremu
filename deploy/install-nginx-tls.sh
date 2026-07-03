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
set_env "VCENTEREMU_PORT" "8182"
set_env "VCENTEREMU_VCENTER_NAME" "${SERVER_NAME}"
chown root:vcenteremu "${ENV_DIR}" "${ENV_FILE}" 2>/dev/null || true
chmod 750 "${ENV_DIR}"
chmod 640 "${ENV_FILE}"

systemctl enable nginx
systemctl restart nginx
systemctl restart vcenteremu 2>/dev/null || true

if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-port=9443/tcp
  firewall-cmd --permanent --add-port=8181/tcp
  firewall-cmd --reload
fi

echo ""
echo "TLS/nginx eingerichtet."
echo "  HTTPS: https://${SERVER_NAME}:9443/"
echo "  API:   https://${SERVER_NAME}:9443/rest/"
echo "  HTTP:  http://${SERVER_NAME}:8181/ (redirects to HTTPS)"
echo ""
echo "Hinweis: Selbstsigniertes Zertifikat — Clients mit curl -k oder CA importieren."
