#!/usr/bin/env bash

set -euo pipefail

LOG_DIR="/var/lib/icp-beta"
LAST_FILE="${LOG_DIR}/last_log_time"
BOOT_FLAG="${LOG_DIR}/boot_sent"
NOW="$(date --utc +%Y-%m-%dT%H:%M:%SZ)"
SINCE="10 minutes ago"
BOOT_LOGS=""

mkdir -p "${LOG_DIR}"

if [[ -f "${LAST_FILE}" ]]; then
    SINCE="$(cat "${LAST_FILE}")"
fi

SYS_LOGS="$(journalctl -p err --since "${SINCE}" --no-pager 2>/dev/null || true)"
KERNEL_LOGS="$(journalctl -k -p err --since "${SINCE}" --no-pager 2>/dev/null || true)"

if [[ ! -f "${BOOT_FLAG}" ]]; then
    BOOT_LOGS="$(journalctl -b --no-pager 2>/dev/null || true)"
    touch "${BOOT_FLAG}"
fi

printf '%s\n' "${NOW}" > "${LAST_FILE}"

python3 - "${NOW}" "${BOOT_LOGS}" "${SYS_LOGS}" "${KERNEL_LOGS}" <<'PY'
import json
import sys

payload = {
    "timestamp": sys.argv[1],
    "logs": {
        "boot": sys.argv[2],
        "system_errors": sys.argv[3],
        "kernel_errors": sys.argv[4],
    },
}

print(json.dumps(payload, ensure_ascii=False))
PY
