#!/usr/bin/env bash
# Standalone diagnosis — works without vcenteremu-ctl in PATH
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/vcenteremu-start.sh" diagnose
