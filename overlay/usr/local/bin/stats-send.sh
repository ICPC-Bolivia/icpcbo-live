#!/usr/bin/env bash

set -euo pipefail

AUTH_ENV_FILE="/etc/contestiso/auth.env"
ICP_REPORT_URL="${ICP_REPORT_URL:-}"
TIMEOUT="10"
BUFFER_DIR="/var/lib/statsbo/pending"
LOGIN_STATE_DIR="/home/icpc/.local/state/icpcbo"

if [[ -f "${AUTH_ENV_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${AUTH_ENV_FILE}"
fi

TIMEOUT="${ICP_REPORT_TIMEOUT:-${TIMEOUT}}"

: "${ICP_REPORT_URL:?ICP_REPORT_URL is required}"

mkdir -p "${BUFFER_DIR}"

DATA_FILE="$(mktemp)"
LOGS_FILE="$(mktemp)"
METRICS_FILE="$(mktemp)"

cleanup() {
    rm -f "${LOGS_FILE}" "${METRICS_FILE}"
}
trap cleanup EXIT

/usr/local/bin/stats-logs.sh > "${LOGS_FILE}"
/usr/local/bin/stats-metrics.sh > "${METRICS_FILE}"

/usr/local/bin/stats-build-payload.py \
    "$(/usr/local/bin/stats-machine-id.sh)" \
    "${LOGS_FILE}" \
    "${METRICS_FILE}" \
    "${LOGIN_STATE_DIR}" > "${DATA_FILE}"

if ! curl --fail --silent --show-error --max-time "${TIMEOUT}" \
    -X POST -H "Content-Type: application/json" \
    -d @"${DATA_FILE}" "${ICP_REPORT_URL}"; then
    mv "${DATA_FILE}" "${BUFFER_DIR}/$(date +%s).json"
else
    rm -f "${DATA_FILE}"
fi

for f in "${BUFFER_DIR}"/*.json; do
    [[ ! -f "${f}" ]] && continue
    if curl --fail --silent --show-error --max-time "${TIMEOUT}" \
        -X POST -H "Content-Type: application/json" \
        -d @"${f}" "${ICP_REPORT_URL}"; then
        rm -f "${f}"
    fi
done
