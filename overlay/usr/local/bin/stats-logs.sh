#!/usr/bin/env bash

set -euo pipefail

LOG_DIR="/var/lib/statsbo"
LAST_FILE="${LOG_DIR}/last_log_time"
BOOT_FLAG="${LOG_DIR}/boot_sent"
NOW="$(date --utc +%Y-%m-%dT%H:%M:%SZ)"
SINCE="10 minutes ago"

mkdir -p "${LOG_DIR}"

if [[ -f "${LAST_FILE}" ]]; then
    SINCE="$(cat "${LAST_FILE}")"
fi

BOOT_LOGS_FILE="$(mktemp)"
SYS_LOGS_FILE="$(mktemp)"
KERNEL_LOGS_FILE="$(mktemp)"

cleanup() {
    rm -f "${BOOT_LOGS_FILE}" "${SYS_LOGS_FILE}" "${KERNEL_LOGS_FILE}"
}
trap cleanup EXIT

journalctl -p err --since "${SINCE}" --no-pager > "${SYS_LOGS_FILE}" 2>/dev/null || true
journalctl -k -p err --since "${SINCE}" --no-pager > "${KERNEL_LOGS_FILE}" 2>/dev/null || true

if [[ ! -f "${BOOT_FLAG}" ]]; then
    journalctl -b --no-pager > "${BOOT_LOGS_FILE}" 2>/dev/null || true
    touch "${BOOT_FLAG}"
fi

printf '%s\n' "${NOW}" > "${LAST_FILE}"

/usr/local/bin/stats-build-logs.py \
    "${NOW}" \
    "${BOOT_LOGS_FILE}" \
    "${SYS_LOGS_FILE}" \
    "${KERNEL_LOGS_FILE}"
