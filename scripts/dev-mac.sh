#!/usr/bin/env bash
# Local development setup and server start (macOS / Cursor)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

log() { printf '[dev-mac] %s\n' "$*"; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found. Install with: brew install python@3.12" >&2
  exit 1
fi

if [[ ! -d .venv ]]; then
  log "Creating virtualenv ..."
  python3 -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate

log "Installing dependencies ..."
pip install -q --upgrade pip
pip install -q -r requirements.txt
pip install -q -e ".[dev]"

mkdir -p uploads

if [[ ! -f .env ]]; then
  log "Creating .env from .env.example ..."
  cp .env.example .env
fi

if [[ -f customer.xlsx ]]; then
  log "Sample file found: customer.xlsx (auto-loaded on startup via .env)"
else
  log "No customer.xlsx in project root — upload via Web UI after start"
fi

PORT="$(grep -E '^VCENTEREMU_PORT=' .env 2>/dev/null | cut -d= -f2- || echo 8443)"
HOST="$(grep -E '^VCENTEREMU_HOST=' .env 2>/dev/null | cut -d= -f2- || echo 127.0.0.1)"

echo ""
echo "============================================"
echo " vCenter Emulator — local dev server"
echo "============================================"
echo " Web UI:  http://${HOST}:${PORT}/"
echo " API:     http://${HOST}:${PORT}/rest/"
echo " Health:  http://${HOST}:${PORT}/health"
echo ""
echo " Stop with Ctrl+C"
echo " Smoke test (new terminal): bash scripts/smoke-test-mac.sh"
echo "============================================"
echo ""

exec uvicorn app.main:app --host "${HOST}" --port "${PORT}" --reload --env-file .env
