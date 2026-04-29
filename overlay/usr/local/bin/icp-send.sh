#!/usr/bin/env bash

set -euo pipefail

REPORT_ENV_FILE="/etc/contestiso/report.env"
API="http://127.0.0.1:8083/report"
TIMEOUT="10"
STATE_DIR="/var/lib/icp-beta"
BUFFER_DIR="${STATE_DIR}/pending"
LOGIN_STATE_DIR="/home/icpc/.local/state/icpcbo"

if [[ -f "${REPORT_ENV_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${REPORT_ENV_FILE}"
fi

API="${ICP_REPORT_URL:-${API}}"
TIMEOUT="${ICP_REPORT_TIMEOUT:-${TIMEOUT}}"
LOGIN_STATE_DIR="${ICP_LOGIN_STATE_DIR:-${LOGIN_STATE_DIR}}"

mkdir -p "${BUFFER_DIR}"

DATA_FILE="$(mktemp)"
LOGS_FILE="$(mktemp)"
METRICS_FILE="$(mktemp)"

cleanup() {
    rm -f "${LOGS_FILE}" "${METRICS_FILE}"
}
trap cleanup EXIT

/usr/local/bin/icp-logs.sh > "${LOGS_FILE}"
/usr/local/bin/icp-metrics.sh > "${METRICS_FILE}"

python3 - "$(/usr/local/bin/icp-machine-id.sh)" "${LOGS_FILE}" "${METRICS_FILE}" "${LOGIN_STATE_DIR}" > "${DATA_FILE}" <<'PY'
import json
import os
import sys

machine_id = sys.argv[1]
logs_file = sys.argv[2]
metrics_file = sys.argv[3]
login_state_dir = sys.argv[4]

def read_optional(path: str) -> str:
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read().strip()
    except FileNotFoundError:
        return ""

with open(logs_file, encoding="utf-8") as fh:
    logs = json.load(fh)

with open(metrics_file, encoding="utf-8") as fh:
    metrics = json.load(fh)

login = {
    "username": read_optional(os.path.join(login_state_dir, "username.txt")),
    "user_id": read_optional(os.path.join(login_state_dir, "user-id.txt")),
    "display_name": read_optional(os.path.join(login_state_dir, "display-name.txt")),
}

payload = {
    "machine_id": machine_id,
    "data": {
        "login": login,
        "metrics": metrics,
        "logs": logs,
    },
}

print(json.dumps(payload, ensure_ascii=False))
PY

if ! curl --fail --silent --show-error --max-time "${TIMEOUT}" \
    -X POST -H "Content-Type: application/json" \
    -d @"${DATA_FILE}" "${API}"; then
    mv "${DATA_FILE}" "${BUFFER_DIR}/$(date +%s).json"
else
    rm -f "${DATA_FILE}"
fi

for f in "${BUFFER_DIR}"/*.json; do
    [[ ! -f "${f}" ]] && continue
    if curl --fail --silent --show-error --max-time "${TIMEOUT}" \
        -X POST -H "Content-Type: application/json" \
        -d @"${f}" "${API}"; then
        rm -f "${f}"
    fi
done
