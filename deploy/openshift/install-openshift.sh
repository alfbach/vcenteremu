#!/usr/bin/env bash
#
# Install vCenter Emulator on OpenShift 4
#
# Usage:
#   ./deploy/openshift/install-openshift.sh [options]
#
# Options:
#   --namespace NAME     Target namespace (default: vcenteremu)
#   --from-git           Build image from Git via BuildConfig (default)
#   --from-image IMAGE   Use pre-built container image instead of building
#   --password PASS      API password (default: prompt)
#   --hostname HOST      Route hostname hint for VCENTEREMU_VCENTER_NAME
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="vcenteremu"
FROM_GIT=true
IMAGE=""
PASSWORD=""
HOSTNAME=""

log()  { printf '[openshift] %s\n' "$*"; }
fail() { printf '[openshift] ERROR: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)  NAMESPACE="${2:?}"; shift 2 ;;
    --from-git)   FROM_GIT=true; IMAGE=""; shift ;;
    --from-image) FROM_GIT=false; IMAGE="${2:?}"; shift 2 ;;
    --password)   PASSWORD="${2:?}"; shift 2 ;;
    --hostname)   HOSTNAME="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) fail "Unknown option: $1" ;;
  esac
done

command -v oc >/dev/null 2>&1 || fail "OpenShift CLI (oc) not found"
oc whoami >/dev/null 2>&1 || fail "Not logged in — run: oc login"

if [[ -z "${PASSWORD}" ]]; then
  read -r -s -p "VCENTEREMU_API_PASSWORD: " PASSWORD
  echo
  [[ -n "${PASSWORD}" ]] || fail "Password required"
fi

log "Creating namespace ${NAMESPACE} ..."
oc apply -f "${SCRIPT_DIR}/namespace.yaml"
oc project "${NAMESPACE}"

log "Creating secret ..."
oc create secret generic vcenteremu-secret \
  --from-literal=VCENTEREMU_API_PASSWORD="${PASSWORD}" \
  --namespace "${NAMESPACE}" \
  --dry-run=client -o yaml | oc apply -f -

log "Applying ConfigMap and PVC ..."
oc apply -f "${SCRIPT_DIR}/configmap.yaml"
if [[ -n "${HOSTNAME}" ]]; then
  oc patch configmap vcenteremu-config -n "${NAMESPACE}" \
    --type merge -p "{\"data\":{\"VCENTEREMU_VCENTER_NAME\":\"${HOSTNAME}\"}}"
fi
oc apply -f "${SCRIPT_DIR}/pvc.yaml"
oc apply -f "${SCRIPT_DIR}/service.yaml"
oc apply -f "${SCRIPT_DIR}/route.yaml"

if [[ "${FROM_GIT}" == true ]]; then
  log "Starting OpenShift build ..."
  oc apply -f "${SCRIPT_DIR}/buildconfig.yaml"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
  if oc start-build vcenteremu --from-dir="${REPO_ROOT}" --wait 2>/dev/null; then
    log "Build from local directory succeeded."
  else
    log "Local dir build unavailable, trying Git source build ..."
    oc start-build vcenteremu --wait
  fi
  IMAGE="image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/vcenteremu:latest"
else
  log "Using external image: ${IMAGE}"
fi

log "Deploying application ..."
oc apply -f "${SCRIPT_DIR}/deployment.yaml"
oc set image deployment/vcenteremu vcenteremu="${IMAGE}" -n "${NAMESPACE}"
oc rollout status deployment/vcenteremu -n "${NAMESPACE}" --timeout=300s

ROUTE="$(oc get route vcenteremu -n "${NAMESPACE}" -o jsonpath='{.spec.host}')"
echo ""
echo "============================================"
echo " vCenter Emulator on OpenShift 4"
echo "============================================"
echo " Web UI:  https://${ROUTE}/"
echo " API:     https://${ROUTE}/rest/"
echo " Health:  https://${ROUTE}/health"
echo ""
echo " Upload an RVtools XLSX file via the web UI."
echo "============================================"
