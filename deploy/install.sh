#!/usr/bin/env bash
#
# vCenter Emulator — full RHEL 10 install script
# Installs OS prerequisites, application, systemd unit, and startup helper.
#
# Usage:
#   sudo bash deploy/install.sh [options]
#
# Options:
#   --with-tls       Also configure nginx + self-signed TLS
#   --with-firewall  Open firewalld ports (8443 or 443 with --with-tls)
#   --hostname NAME  Hostname/FQDN for TLS and vCenter name (default: hostname -f)
#   --app-dir PATH   Install path (default: /opt/vcenteremu)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_DIR="/opt/vcenteremu"
DATA_DIR="/var/lib/vcenteremu/uploads"
LOG_DIR="/var/log/vcenteremu"
RUN_DIR="/run/vcenteremu"
ENV_DIR="/etc/vcenteremu"
ENV_FILE="${ENV_DIR}/vcenteremu.env"
SERVICE_USER="vcenteremu"
SERVICE_NAME="vcenteremu"
CTL_BIN="/usr/local/bin/vcenteremu-ctl"

WITH_TLS=false
WITH_FIREWALL=false
HOSTNAME="$(hostname -f 2>/dev/null || hostname)"

log()  { printf '[vcenteremu] %s\n' "$*"; }
fail() { printf '[vcenteremu] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-tls)       WITH_TLS=true; shift ;;
    --with-firewall)  WITH_FIREWALL=true; shift ;;
    --hostname)       HOSTNAME="${2:?--hostname requires a value}"; shift 2 ;;
    --app-dir)        APP_DIR="${2:?--app-dir requires a value}"; shift 2 ;;
    -h|--help)        usage ;;
    *)                fail "Unknown option: $1 (use --help)" ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  fail "Bitte als root ausführen: sudo bash deploy/install.sh"
fi

# --- OS check ---
if [[ -f /etc/redhat-release ]]; then
  log "Detected: $(tr -d '\n' < /etc/redhat-release)"
else
  log "Warnung: Kein RHEL/CentOS/Alma/Rocky erkannt — Installation wird trotzdem fortgesetzt."
fi

# --- Package prerequisites ---
log "Installiere System-Pakete (RHEL 10 Voraussetzungen) ..."
PACKAGES=(
  python3
  python3-pip
  python3-devel
  gcc
  gcc-c++
  make
  openssl
  tar
  gzip
  curl
  rsync
  shadow-utils
  systemd
)

# Optional but useful on RHEL
if dnf list available policycoreutils-python-utils &>/dev/null; then
  PACKAGES+=(policycoreutils-python-utils)
fi

dnf install -y "${PACKAGES[@]}"

PYTHON_BIN="$(command -v python3)"
PYTHON_VERSION="$("${PYTHON_BIN}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
log "Python ${PYTHON_VERSION} unter ${PYTHON_BIN}"

# Python 3.11+ required
"${PYTHON_BIN}" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' \
  || fail "Python >= 3.11 erforderlich (gefunden: ${PYTHON_VERSION})"

# --- Service user ---
if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
  log "Lege Systembenutzer ${SERVICE_USER} an ..."
  useradd --system --home-dir "${APP_DIR}" --shell /sbin/nologin "${SERVICE_USER}"
fi

# --- Directories ---
log "Erstelle Verzeichnisse ..."
mkdir -p "${APP_DIR}" "${DATA_DIR}" "${LOG_DIR}" "${RUN_DIR}" "${ENV_DIR}"

# --- Application files ---
log "Kopiere Anwendung nach ${APP_DIR} ..."
rsync -a --delete \
  --exclude '.venv' \
  --exclude '.git' \
  --exclude '__pycache__' \
  --exclude '.pytest_cache' \
  --exclude '*.egg-info' \
  --exclude 'uploads' \
  "${REPO_ROOT}/" "${APP_DIR}/"

# --- Environment file ---
if [[ ! -f "${ENV_FILE}" ]]; then
  log "Erstelle ${ENV_FILE} ..."
  cat > "${ENV_FILE}" <<EOF
VCENTEREMU_HOST=0.0.0.0
VCENTEREMU_PORT=8443
VCENTEREMU_WORKERS=4
VCENTEREMU_UPLOAD_DIR=${DATA_DIR}
VCENTEREMU_API_USERNAME=administrator@vsphere.local
VCENTEREMU_API_PASSWORD=Emulator123!
VCENTEREMU_VCENTER_NAME=${HOSTNAME}
VCENTEREMU_MAX_UPLOAD_MB=256
EOF
  chmod 640 "${ENV_FILE}"
else
  log "Behalte vorhandene Konfiguration: ${ENV_FILE}"
fi

# --- Python virtualenv ---
log "Erstelle Python venv und installiere Abhängigkeiten ..."
"${PYTHON_BIN}" -m venv "${APP_DIR}/.venv"
"${APP_DIR}/.venv/bin/pip" install --upgrade pip setuptools wheel
"${APP_DIR}/.venv/bin/pip" install -r "${APP_DIR}/requirements.txt"
"${APP_DIR}/.venv/bin/pip" install "${APP_DIR}"

# --- Startup script + control wrapper ---
log "Installiere Startup-Skript ..."
install -m 755 "${APP_DIR}/deploy/vcenteremu-start.sh" "${CTL_BIN}"

# --- systemd unit ---
log "Installiere systemd Service ..."
install -m 644 "${APP_DIR}/deploy/vcenteremu.service" "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"

# --- Permissions ---
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${APP_DIR}" "${DATA_DIR}" "${LOG_DIR}"
chmod 750 "${DATA_DIR}" "${LOG_DIR}"
chmod 755 "${RUN_DIR}"

# SELinux: allow nginx to connect to backend if TLS is used later
if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce)" != "Disabled" ]]; then
  if command -v semanage >/dev/null 2>&1; then
    semanage port -a -t http_port_t -p tcp 8443 2>/dev/null || \
    semanage port -m -t http_port_t -p tcp 8443 2>/dev/null || true
    semanage port -a -t http_port_t -p tcp 8080 2>/dev/null || \
    semanage port -m -t http_port_t -p tcp 8080 2>/dev/null || true
  fi
fi

# --- TLS (optional) ---
if [[ "${WITH_TLS}" == true ]]; then
  log "Konfiguriere TLS/nginx ..."
  bash "${APP_DIR}/deploy/install-nginx-tls.sh" "${HOSTNAME}"
fi

# --- Firewall (optional) ---
if [[ "${WITH_FIREWALL}" == true ]]; then
  if systemctl is-active --quiet firewalld; then
    log "Öffne firewalld-Ports ..."
    if [[ "${WITH_TLS}" == true ]]; then
      firewall-cmd --permanent --add-service=https
      firewall-cmd --permanent --add-service=http
    else
      firewall-cmd --permanent --add-port=8443/tcp
    fi
    firewall-cmd --reload
  else
    log "firewalld nicht aktiv — überspringe Firewall-Konfiguration."
  fi
fi

# --- Start service ---
log "Starte ${SERVICE_NAME} ..."
systemctl restart "${SERVICE_NAME}.service"

sleep 1
if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
  log "Service läuft."
else
  fail "Service konnte nicht gestartet werden. Prüfen: journalctl -u ${SERVICE_NAME} -n 50"
fi

# --- Health check ---
HEALTH_URL="http://127.0.0.1:8443/health"
if [[ "${WITH_TLS}" == true ]]; then
  HEALTH_URL="https://127.0.0.1/health"
fi

if curl -sk --max-time 5 "${HEALTH_URL}" >/dev/null 2>&1; then
  log "Health-Check OK: ${HEALTH_URL}"
else
  log "Health-Check fehlgeschlagen (Service evtl. noch am Starten): ${HEALTH_URL}"
fi

echo ""
echo "============================================"
echo " vCenter Emulator — Installation abgeschlossen"
echo "============================================"
if [[ "${WITH_TLS}" == true ]]; then
  echo " Web-UI:  https://${HOSTNAME}/"
  echo " API:     https://${HOSTNAME}/rest/"
else
  echo " Web-UI:  http://${HOSTNAME}:8443/"
  echo " API:     http://${HOSTNAME}:8443/rest/"
fi
echo ""
echo " Steuerung:"
echo "   systemctl status ${SERVICE_NAME}"
echo "   vcenteremu-ctl status|start|stop|restart|foreground"
echo ""
echo " Konfiguration: ${ENV_FILE}"
echo " Logs:          journalctl -u ${SERVICE_NAME} -f"
echo "               ${LOG_DIR}/"
echo "============================================"
