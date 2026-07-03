#!/usr/bin/env bash
set -euo pipefail

TLS_DIR="/etc/vcenteremu/tls"
ENV_DIR="/etc/vcenteremu"
CN="${1:-vcenteremu.local}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Bitte als root ausführen (sudo)."
  exit 1
fi

mkdir -p "${TLS_DIR}"

if [[ ! -f "${TLS_DIR}/cert.pem" || ! -f "${TLS_DIR}/key.pem" ]]; then
  echo "Erzeuge selbstsigniertes Zertifikat für CN=${CN} ..."
  openssl req -x509 -nodes -days 825 -newkey rsa:4096 \
    -keyout "${TLS_DIR}/key.pem" \
    -out "${TLS_DIR}/cert.pem" \
    -subj "/CN=${CN}/O=vCenter Emulator/C=DE"
  chmod 640 "${TLS_DIR}/key.pem"
  chmod 644 "${TLS_DIR}/cert.pem"
else
  echo "TLS-Zertifikate existieren bereits in ${TLS_DIR}"
fi

echo "Zertifikat: ${TLS_DIR}/cert.pem"
echo "Schlüssel:  ${TLS_DIR}/key.pem"
