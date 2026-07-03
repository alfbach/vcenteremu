#!/usr/bin/env bash
#
# vCenter Emulator — full RHEL 10 uninstall script
# Removes systemd service, application files, nginx/TLS integration, and optionally
# configuration, data, logs, and the service user.
#
# Usage:
#   sudo bash deploy/uninstall.sh [options]
#
# Options:
#   --purge          Also remove config (/etc/vcenteremu), data, logs, and user
#   --keep-data      Keep upload data (/var/lib/vcenteremu/uploads) even with --purge
#   --app-dir PATH   Application path (default: /opt/vcenteremu)
#   --yes, -y        Do not ask for confirmation
#   -h, --help       Show help
#
set -euo pipefail

APP_DIR="/opt/vcenteremu"
DATA_ROOT="/var/lib/vcenteremu"
DATA_DIR="${DATA_ROOT}/uploads"
STATE_DIR="${DATA_ROOT}/run"
LOG_DIR="/var/log/vcenteremu"
ENV_DIR="/etc/vcenteremu"
ENV_FILE="${ENV_DIR}/vcenteremu.env"
TLS_DIR="${ENV_DIR}/tls"
SERVICE_USER="vcenteremu"
SERVICE_NAME="vcenteremu"
CTL_BIN="/usr/bin/vcenteremu-ctl"
DIAG_BIN="/usr/bin/vcenteremu-diagnose"
LEGACY_CTL="/usr/local/bin/vcenteremu-ctl"
SYSTEMD_UNIT="/etc/systemd/system/${SERVICE_NAME}.service"
TMPFILES_CONF="/etc/tmpfiles.d/vcenteremu.conf"
NGINX_CONF="/etc/nginx/conf.d/vcenteremu.conf"

PURGE=false
KEEP_DATA=false
ASSUME_YES=false

log()  { printf '[vcenteremu-uninstall] %s\n' "$*"; }
warn() { printf '[vcenteremu-uninstall] WARNUNG: %s\n' "$*" >&2; }
fail() { printf '[vcenteremu-uninstall] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge)     PURGE=true; shift ;;
    --keep-data) KEEP_DATA=true; shift ;;
    --app-dir)   APP_DIR="${2:?--app-dir requires a value}"; shift 2 ;;
    --yes|-y)    ASSUME_YES=true; shift ;;
    -h|--help)   usage ;;
    *)           fail "Unknown option: $1 (use --help)" ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  fail "Bitte als root ausführen: sudo bash deploy/uninstall.sh"
fi

confirm() {
  local prompt="$1"
  if [[ "${ASSUME_YES}" == true ]]; then
    return 0
  fi
  printf '[vcenteremu-uninstall] %s [y/N] ' "${prompt}"
  read -r reply
  [[ "${reply}" =~ ^[Yy]$ ]]
}

remove_path() {
  local path="$1"
  if [[ -e "${path}" || -L "${path}" ]]; then
    log "Entferne ${path} ..."
    rm -rf "${path}"
  fi
}

remove_firewall_ports() {
  if ! systemctl is-active --quiet firewalld 2>/dev/null; then
    return
  fi
  log "Entferne firewalld-Ports 8181/tcp und 9443/tcp ..."
  firewall-cmd --permanent --remove-port=8181/tcp 2>/dev/null || true
  firewall-cmd --permanent --remove-port=9443/tcp 2>/dev/null || true
  firewall-cmd --reload 2>/dev/null || true
}

remove_nginx_integration() {
  if [[ -f "${NGINX_CONF}" ]]; then
    log "Entferne nginx-Config ${NGINX_CONF} ..."
    rm -f "${NGINX_CONF}"
    if systemctl is-active --quiet nginx 2>/dev/null; then
      nginx -t 2>/dev/null && systemctl reload nginx || systemctl restart nginx || true
    fi
  fi
}

remove_selinux_ports() {
  if ! command -v getenforce >/dev/null 2>&1; then
    return
  fi
  if [[ "$(getenforce)" == "Disabled" ]]; then
    return
  fi
  if ! command -v semanage >/dev/null 2>&1; then
    return
  fi
  log "Entferne SELinux-Port-Labels 8181/tcp und 9443/tcp (falls gesetzt) ..."
  semanage port -d -t http_port_t -p tcp 8181 2>/dev/null || true
  semanage port -d -t http_port_t -p tcp 9443 2>/dev/null || true
}

echo ""
echo "============================================"
echo " vCenter Emulator — Deinstallation (RHEL 10)"
echo "============================================"
echo " Service:     ${SERVICE_NAME}"
echo " App:         ${APP_DIR}"
echo " Config:      ${ENV_DIR}"
echo " Daten:       ${DATA_ROOT}"
echo " Logs:        ${LOG_DIR}"
if [[ "${PURGE}" == true ]]; then
  echo " Modus:       PURGE (Config/Daten/Logs/User)"
  if [[ "${KEEP_DATA}" == true ]]; then
    echo " Ausnahme:    Uploads bleiben erhalten (${DATA_DIR})"
  fi
else
  echo " Modus:       Standard (Config/Daten/Logs bleiben erhalten)"
  echo "              Vollständig entfernen: --purge"
fi
echo "============================================"
echo ""

if ! confirm "Deinstallation fortsetzen?"; then
  log "Abgebrochen."
  exit 0
fi

# --- Stop and disable service ---
if systemctl list-unit-files "${SERVICE_NAME}.service" &>/dev/null; then
  log "Stoppe und deaktiviere ${SERVICE_NAME}.service ..."
  systemctl stop "${SERVICE_NAME}.service" 2>/dev/null || true
  systemctl disable "${SERVICE_NAME}.service" 2>/dev/null || true
fi

# --- systemd unit ---
remove_path "${SYSTEMD_UNIT}"
systemctl daemon-reload 2>/dev/null || true
systemctl reset-failed "${SERVICE_NAME}.service" 2>/dev/null || true

# --- tmpfiles.d ---
remove_path "${TMPFILES_CONF}"

# --- Control scripts ---
remove_path "${CTL_BIN}"
remove_path "${DIAG_BIN}"
remove_path "${LEGACY_CTL}"

# --- nginx / TLS integration ---
remove_nginx_integration
remove_firewall_ports
remove_selinux_ports

# --- Application ---
remove_path "${APP_DIR}"

# --- Optional purge ---
if [[ "${PURGE}" == true ]]; then
  remove_path "${STATE_DIR}"
  remove_path "${LOG_DIR}"
  remove_path "${TLS_DIR}"
  remove_path "${ENV_FILE}"

  if [[ "${KEEP_DATA}" == true ]]; then
    log "Behalte Upload-Daten: ${DATA_DIR}"
    if [[ -d "${ENV_DIR}" ]] && [[ -z "$(find "${ENV_DIR}" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)" ]]; then
      remove_path "${ENV_DIR}"
    fi
  else
    remove_path "${ENV_DIR}"
    remove_path "${DATA_ROOT}"
  fi

  if id "${SERVICE_USER}" &>/dev/null; then
    log "Entferne Systembenutzer ${SERVICE_USER} ..."
    userdel "${SERVICE_USER}" 2>/dev/null || warn "User ${SERVICE_USER} konnte nicht entfernt werden."
  fi
else
  log "Behalte Konfiguration: ${ENV_DIR}"
  log "Behalte Daten:         ${DATA_ROOT}"
  log "Behalte Logs:          ${LOG_DIR}"
  log "Vollständig entfernen: sudo bash deploy/uninstall.sh --purge --yes"
fi

echo ""
echo "============================================"
echo " Deinstallation abgeschlossen"
echo "============================================"
if [[ "${PURGE}" == true ]]; then
  echo " vcenteremu wurde vollständig entfernt."
else
  echo " Service und Anwendung entfernt."
  echo " Config/Daten/Logs wurden beibehalten."
fi
echo ""
echo " Hinweis: System-Pakete (python3, nginx, gcc, …) werden"
echo "          nicht deinstalliert — ggf. manuell per dnf remove."
echo "============================================"
