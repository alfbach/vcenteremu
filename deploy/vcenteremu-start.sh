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
  if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
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
  if is_running; then
    log "Läuft (PID $(cat "${PID_FILE}")) — http://${VCENTEREMU_HOST}:${VCENTEREMU_PORT}/"
    return 0
  fi
  log "Gestoppt."
  return 1
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  start       Startet den Emulator im Hintergrund (manuell, ohne systemd)
  stop        Stoppt den manuell gestarteten Emulator
  restart     Neustart (manuell)
  status      Zeigt den Prozessstatus
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
  foreground) start_foreground ;;
  *)          usage ;;
esac
