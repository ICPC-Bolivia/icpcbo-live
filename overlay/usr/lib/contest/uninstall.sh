#!/usr/bin/env bash
# Removes the contest runtime deployment from a disk partition.
#
# Triggered by contest-uninstall.service when booting with contest.uninstall=1.
# Shows a 10-second countdown — reboot to cancel.

set -euo pipefail

. /usr/lib/contest/common.sh

LOG="/var/log/contest-uninstall.log"
MARKER=".contest-installed"
MOUNT_TMP="/mnt/contest-uninstall-target"

_log() {
    local ts
    ts=$(date -u +%H:%M:%S)
    echo "[${ts}] $*" | tee -a "${LOG}"
    # Also write directly to console so the message is visible before GDM starts.
    echo "[${ts}] contest-uninstall: $*" > /dev/console || true
}
_warn() { _log "WARN: $*"; }
_die()  { _log "FATAL: $*"; exit 1; }

mkdir -p "$(dirname "${LOG}")"
[ "$(id -u)" -eq 0 ] || _die "Must run as root"

cleanup_mount() {
    if mountpoint -q "${MOUNT_TMP}" 2>/dev/null; then
        umount "${MOUNT_TMP}" || true
    fi
}
trap cleanup_mount EXIT

CONTEST_DIR="$(cmdline_param contest_dir)"
CONTEST_DIR="$(normalize_contest_dir "${CONTEST_DIR:-/contest}")"

# ----------------------------------------------------------------
# 10-second abort window — reboot now to cancel
# ----------------------------------------------------------------
_log "======================================"
_log " CONTEST UNINSTALL STARTED"
_log "======================================"
_log "Will remove '${CONTEST_DIR}' from local disk in 10 seconds."
_log "Reboot NOW to cancel."
sleep 10
_log "Proceeding with cleanup..."

# ----------------------------------------------------------------
# Find the contest media device
# ----------------------------------------------------------------
CONTEST_DEV="$(awk '$2=="/run/contest-media" {print $1; exit}' /proc/mounts)"
[ -n "${CONTEST_DEV}" ] || _die "Cannot determine contest media device (/run/contest-media not in /proc/mounts)"

# ----------------------------------------------------------------
# Mount the partition read-write at a separate mountpoint.
# (The existing /run/contest-media mount stays read-only; the
#  squashfs loop-mount keeps working until reboot.)
# ----------------------------------------------------------------
mkdir -p "${MOUNT_TMP}"
mount -o rw "${CONTEST_DEV}" "${MOUNT_TMP}" || _die "Cannot mount ${CONTEST_DEV} read-write"

MARKER_FILE="${MOUNT_TMP}${CONTEST_DIR}/${MARKER}"
if [ ! -f "${MARKER_FILE}" ]; then
    _die "No deployment marker found at ${MARKER_FILE}. Aborting (not a managed install)."
fi

read_install_marker "${MARKER_FILE}"

_log "Removing ${CONTEST_DIR} from ${CONTEST_DEV} ..."
rm -rf "${MOUNT_TMP}${CONTEST_DIR:?}" 2>&1 | tee -a "${LOG}" || true
cleanup_mount
_log "Contest folder removed."

# ----------------------------------------------------------------
# Remove EFI boot entry and GRUB files
# ----------------------------------------------------------------
if [ -d /sys/firmware/efi ] && command -v efibootmgr >/dev/null 2>&1; then
    if [ -n "${MARKER_EFI_BOOT_NUM:-}" ]; then
        _log "Removing EFI boot entry Boot${MARKER_EFI_BOOT_NUM} ..."
        efibootmgr --delete-bootnum "${MARKER_EFI_BOOT_NUM}" 2>&1 | tee -a "${LOG}" || \
            _warn "Could not delete EFI entry Boot${MARKER_EFI_BOOT_NUM} (may already be gone)"
    fi

    EFI_MNT="$(findmnt -n -o TARGET /boot/efi 2>/dev/null || true)"
    if [ -n "${EFI_MNT}" ] && [ -d "${EFI_MNT}/EFI/icpc-bolivia-debian" ]; then
        _log "Removing GRUB EFI files from ${EFI_MNT}/EFI/icpc-bolivia-debian ..."
        rm -rf "${EFI_MNT}/EFI/icpc-bolivia-debian" || true
    fi
fi

_log "Cleanup complete. Rebooting in 5 seconds."
sleep 5
reboot
