#!/usr/bin/env bash
#
# vCenter Emulator — startup / control script
#
# Usage:
#   vcenteremu-ctl start|stop|restart|status|foreground
#
# Environment: /etc/vcenteremu/vcenteremu.env
#
set -euo pipefail

APP_DIR="${VCENTEREMU_APP_DIR:-/opt/vcenteremu}"
ENV_FILE="${VCENTEREMU_ENV_FILE:-/etc/vcenteremu/vcenteremu.env}"
PID_FILE="${VCENTEREMU_PID_FILE:-/var/lib/vcenteremu/run/vcenteremu.pid}"
LOG_DIR="${VCENTEREMU_LOG_DIR:-/var/log/vcenteremu}"
RUN_DIR="$(dirname "${PID_FILE}")"
SERVICE_USER="${VCENTEREMU_USER:-vcenteremu}"
VENV_BIN="${APP_DIR}/.venv/bin"
VCENTEREMU_BIN="${VENV_BIN}/vcenteremu"

log()  { printf '[vcenteremu-ctl] %s\n' "$*"; }
fail() { printf '[vcenteremu-ctl] ERROR: %s\n' "$*" >&2; exit 1; }

load_env() {
  if [[ -f "${ENV_FILE}" ]] && [[ -r "${ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
  elif [[ -f "${ENV_FILE}" ]]; then
    log "Warnung: ${ENV_FILE} nicht lesbar — chown root:vcenteremu ${ENV_FILE}"
  fi

  export VCENTEREMU_HOST="${VCENTEREMU_HOST:-0.0.0.0}"
  export VCENTEREMU_PORT="${VCENTEREMU_PORT:-8181}"
  export VCENTEREMU_WORKERS="${VCENTEREMU_WORKERS:-1}"
  export VCENTEREMU_UPLOAD_DIR="${VCENTEREMU_UPLOAD_DIR:-/var/lib/vcenteremu/uploads}"
}

preflight() {
  [[ -x "${VCENTEREMU_BIN}" ]] || fail "Application not installed: ${VCENTEREMU_BIN}"
  if [[ "${EUID}" -eq 0 ]]; then
    mkdir -p "${LOG_DIR}" "${RUN_DIR}" "${VCENTEREMU_UPLOAD_DIR}"
    chown -R "${SERVICE_USER}:${SERVICE_USER}" "${LOG_DIR}" "${RUN_DIR}" "${VCENTEREMU_UPLOAD_DIR}" 2>/dev/null || true
  else
    mkdir -p "${LOG_DIR}" "${RUN_DIR}" "${VCENTEREMU_UPLOAD_DIR}" 2>/dev/null || true
  fi
}

is_running() {
  [[ -f "${PID_FILE}" ]] || return 1
  local pid
  pid="$(cat "${PID_FILE}")"
  kill -0 "${pid}" 2>/dev/null
}

start_foreground() {
  load_env
  preflight
  cd "${APP_DIR}"
  exec "${VCENTEREMU_BIN}"
}

start_daemon() {
  load_env
  preflight

  if is_running; then
    log "Bereits gestartet (PID $(cat "${PID_FILE}"))."
    return 0
  fi

  log "Starte vCenter Emulator ..."
  cd "${APP_DIR}"

  if [[ "${EUID}" -eq 0 ]]; then
    nohup runuser -u "${SERVICE_USER}" -- env \
      VCENTEREMU_HOST="${VCENTEREMU_HOST}" \
      VCENTEREMU_PORT="${VCENTEREMU_PORT}" \
      VCENTEREMU_WORKERS="${VCENTEREMU_WORKERS}" \
      VCENTEREMU_UPLOAD_DIR="${VCENTEREMU_UPLOAD_DIR}" \
      "${VCENTEREMU_BIN}" \
      >> "${LOG_DIR}/vcenteremu.log" 2>&1 &
  else
    nohup env \
      VCENTEREMU_HOST="${VCENTEREMU_HOST}" \
      VCENTEREMU_PORT="${VCENTEREMU_PORT}" \
      VCENTEREMU_WORKERS="${VCENTEREMU_WORKERS}" \
      VCENTEREMU_UPLOAD_DIR="${VCENTEREMU_UPLOAD_DIR}" \
      "${VCENTEREMU_BIN}" \
      >> "${LOG_DIR}/vcenteremu.log" 2>&1 &
  fi

  echo $! > "${PID_FILE}"
  sleep 1

  if is_running; then
    log "Gestartet (PID $(cat "${PID_FILE}"))."
    log "Web-UI: http://${VCENTEREMU_HOST}:${VCENTEREMU_PORT}/"
  else
    rm -f "${PID_FILE}"
    fail "Start fehlgeschlagen. Siehe ${LOG_DIR}/vcenteremu.log"
  fi
}

stop_daemon() {
  if ! is_running; then
    log "Nicht gestartet."
    rm -f "${PID_FILE}"
    return 0
  fi

  local pid
  pid="$(cat "${PID_FILE}")"
  log "Stoppe Prozess ${pid} ..."
  kill "${pid}" 2>/dev/null || true

  for _ in $(seq 1 20); do
    if ! kill -0 "${pid}" 2>/dev/null; then
      rm -f "${PID_FILE}"
      log "Gestoppt."
      return 0
    fi
    sleep 0.5
  done

  log "Erzwinge Stopp ..."
  kill -9 "${pid}" 2>/dev/null || true
  rm -f "${PID_FILE}"
  log "Gestoppt (SIGKILL)."
}

status_daemon() {
  load_env
  if systemctl is-active --quiet vcenteremu 2>/dev/null; then
    log "systemd: vcenteremu.service läuft"
  elif is_running; then
    log "Manueller Prozess (PID $(cat "${PID_FILE}"))"
  else
    log "Gestoppt (weder systemd noch manueller Prozess)."
  fi
  log "Konfiguration: ${VCENTEREMU_HOST}:${VCENTEREMU_PORT} (env: ${ENV_FILE})"
  if command -v ss >/dev/null 2>&1; then
    ss -tlnp 2>/dev/null | grep -E ':8181|:8182|:9443' || log "Kein Listener auf 8181/8182/9443"
  fi
  if [[ "${VCENTEREMU_PORT}" == "8182" ]] && [[ "${VCENTEREMU_HOST}" != "0.0.0.0" ]]; then
    log "TLS-Backend-Modus: Web-UI über https://<host>:9443/ (nicht direkt :8181)"
  fi
  if is_running || systemctl is-active --quiet vcenteremu 2>/dev/null; then
    log "URL: http://${VCENTEREMU_HOST}:${VCENTEREMU_PORT}/"
    return 0
  fi
  return 1
}

diagnose() {
  load_env
  log "=== vcenteremu Diagnose ==="
  log "Env-Datei: ${ENV_FILE}"
  log "Bind: ${VCENTEREMU_HOST}:${VCENTEREMU_PORT}  Workers: ${VCENTEREMU_WORKERS}"
  log "App: ${VCENTEREMU_BIN} ($([[ -x "${VCENTEREMU_BIN}" ]] && echo OK || echo FEHLT))"

  if systemctl is-active --quiet vcenteremu 2>/dev/null; then
    log "systemd: active"
  else
    log "systemd: $(systemctl is-active vcenteremu 2>/dev/null || echo nicht verfügbar)"
    log "Letzte Logs:"
    journalctl -u vcenteremu -n 15 --no-pager 2>/dev/null || true
  fi

  if [[ -f /etc/nginx/conf.d/vcenteremu.conf ]]; then
    log "nginx vcenteremu.conf: vorhanden (8181/9443 → Backend 8182)"
    systemctl is-active nginx 2>/dev/null && log "nginx: active" || log "nginx: inactive — Port 8181 antwortet nicht im TLS-Modus!"
  else
    log "nginx vcenteremu.conf: nicht vorhanden (direkter HTTP auf App-Port)"
  fi

  if command -v ss >/dev/null 2>&1; then
    log "Listener:"
    ss -tlnp 2>/dev/null | grep -E ':8181|:8182|:9443' || log "  keine auf 8181/8182/9443"
  fi

  local health_host="127.0.0.1"
  local health_port="${VCENTEREMU_PORT}"
  if [[ -f /etc/nginx/conf.d/vcenteremu.conf ]] && systemctl is-active --quiet nginx 2>/dev/null; then
    health_port="9443"
    log "Health (HTTPS): curl -sk https://127.0.0.1:9443/health"
    curl -sk --max-time 3 "https://127.0.0.1:9443/health" 2>/dev/null && log "  → OK" || log "  → FEHLER"
  fi
  log "Health (App): curl -s http://${health_host}:${health_port}/health"
  curl -s --max-time 3 "http://${health_host}:${health_port}/health" 2>/dev/null && log "  → OK" || log "  → FEHLER"

  if systemctl is-active --quiet firewalld 2>/dev/null; then
    log "firewalld aktiv — Ports:"
    firewall-cmd --list-ports 2>/dev/null || true
  fi

  if [[ "${VCENTEREMU_HOST}" == "127.0.0.1" ]] && [[ ! -f /etc/nginx/conf.d/vcenteremu.conf ]]; then
    log "HINWEIS: App bindet nur localhost — von außen nicht erreichbar."
    log "Fix: VCENTEREMU_HOST=0.0.0.0 und VCENTEREMU_PORT=8181 in ${ENV_FILE}, dann systemctl restart vcenteremu"
  fi

  if ss -tlnp 2>/dev/null | grep -q ':8181'; then
    log "Port 8181 belegt von:"
    ss -tlnp 2>/dev/null | grep ':8181' || true
    log "Fix: systemctl stop vcenteremu; sudo fuser -k 8181/tcp; systemctl start vcenteremu"
  fi

  if [[ -f "${ENV_FILE}" ]] && ! sudo -u "${SERVICE_USER}" test -r "${ENV_FILE}" 2>/dev/null; then
    log "HINWEIS: ${ENV_FILE} für User ${SERVICE_USER} nicht lesbar"
    log "Fix: chown root:${SERVICE_USER} ${ENV_FILE} && chmod 640 ${ENV_FILE} && chmod 750 ${ENV_DIR:-/etc/vcenteremu}"
  fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  start       Startet den Emulator im Hintergrund (manuell, ohne systemd)
  stop        Stoppt den manuell gestarteten Emulator
  restart     Neustart (manuell)
  status      Zeigt den Prozessstatus
  diagnose    Port-, Config- und Health-Check (Fehlersuche)
  foreground  Startet im Vordergrund (für systemd / Debugging)

Empfohlen für Produktion: systemctl start vcenteremu
EOF
  exit 1
}

CMD="${1:-}"
case "${CMD}" in
  start)      start_daemon ;;
  stop)       stop_daemon ;;
  restart)    stop_daemon; start_daemon ;;
  status)     status_daemon ;;
  diagnose)   diagnose ;;
  foreground) start_foreground ;;
  *)          usage ;;
esac
