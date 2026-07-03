#!/usr/bin/env bash
# Backward-compatible wrapper — use deploy/uninstall.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/uninstall.sh" "$@"
