#!/usr/bin/env bash
# Quick API smoke test against local dev server
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
fi

HOST="${VCENTEREMU_HOST:-127.0.0.1}"
PORT="${VCENTEREMU_PORT:-8181}"
BASE="http://${HOST}:${PORT}"
USER="${VCENTEREMU_API_USERNAME:-administrator@vsphere.local}"
PASS="${VCENTEREMU_API_PASSWORD:-Emulator123!}"

pass() { printf '  ✓ %s\n' "$*"; }
fail() { printf '  ✗ %s\n' "$*" >&2; exit 1; }

echo "Smoke test: ${BASE}"
echo ""

health="$(curl -sf "${BASE}/health")" || fail "Health check failed — is the server running?"
pass "Health: ${health}"

token="$(curl -sf -u "${USER}:${PASS}" -X POST "${BASE}/rest/com/vmware/cis/session")" || fail "Session login failed"
token="${token//\"/}"
[[ -n "${token}" ]] || fail "Empty session token"
pass "Session token received"

vm_count="$(curl -sf -H "vmware-api-session-id: ${token}" "${BASE}/rest/vcenter/vm" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
pass "VM list: ${vm_count} VMs"

host_count="$(curl -sf -H "vmware-api-session-id: ${token}" "${BASE}/rest/vcenter/host" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
pass "Host list: ${host_count} hosts"

version="$(curl -sf -H "vmware-api-session-id: ${token}" "${BASE}/rest/appliance/system/version" | python3 -c 'import json,sys; print(json.load(sys.stdin)["value"]["version"])')"
pass "Appliance version: ${version}"

echo ""
echo "All smoke tests passed."
