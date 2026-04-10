#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
source "${PROJECT_DIR}/config/iso.conf"
# shellcheck source=/dev/null
source "${PROJECT_DIR}/scripts/build/grub.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_file_equals() {
    local expected="$1"
    local actual_file="$2"
    local label="$3"

    local actual
    actual="$(cat "${actual_file}")"

    if [[ "${actual}" != "${expected}" ]]; then
        printf 'Expected %s:\n%s\n' "${label}" "${expected}" >&2
        printf 'Actual %s:\n%s\n' "${label}" "${actual}" >&2
        fail "${label} does not match expected content"
    fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

runtime_grub="${tmp_dir}/grub-entry.cfg"
iso_grub="${tmp_dir}/grub.cfg"

write_runtime_grub_entry "${runtime_grub}"
write_iso_grub_cfg "${iso_grub}"

boot_persistent_title="${ISO_NAME} - Iniciar el sistema persistente en disco"
install_persistent_title="${ISO_NAME} - Instalar el sistema persistente en disco"
clean_home_title="${ISO_NAME} - Limpiar el home de icpcbo"
uninstall_title="${ISO_NAME} - Eliminar los archivos instalados de icpcbo"

expected_runtime_grub="$(cat <<EOF_RUNTIME
menuentry "${ISO_NAME} (folder mode)" {
    linux /${CONTEST_DIR}/vmlinuz quiet splash contest_dir=/${CONTEST_DIR} contest_root=${ROOT_SQUASH_NAME} contest_persist=auto
    initrd /${CONTEST_DIR}/initrd.img
}
EOF_RUNTIME
)"

expected_iso_grub="$(cat <<EOF_ISO
set default=0
set timeout=30
set timeout_style=menu

# Detect an already-deployed runtime on any local partition.
# The marker is only written by deploy.sh — never present on the ISO itself.
echo "Buscando instalacion en disco local..."
search --no-floppy --set=hdd_root --file /${CONTEST_DIR}/.contest-installed

if [ -n "\${hdd_root}" ]; then

    # ── Operacion principal ───────────────────────────────────────────────
    menuentry "${boot_persistent_title}" {
        set root=(\${hdd_root})
        linux /${CONTEST_DIR}/vmlinuz quiet splash contest_dir=/${CONTEST_DIR} contest_root=${ROOT_SQUASH_NAME} contest_persist=on
        initrd /${CONTEST_DIR}/initrd.img
    }

    # ── Mantenimiento ──────────────────────────────────────────────────────
    menuentry "${clean_home_title}" {
        set root=(\${hdd_root})
        linux /${CONTEST_DIR}/vmlinuz quiet contest_dir=/${CONTEST_DIR} contest_root=${ROOT_SQUASH_NAME} contest_persist=on contest.clean_home=1
        initrd /${CONTEST_DIR}/initrd.img
    }

    menuentry "${uninstall_title}" {
        set root=(\${hdd_root})
        linux /${CONTEST_DIR}/vmlinuz quiet contest_dir=/${CONTEST_DIR} contest_root=${ROOT_SQUASH_NAME} contest_persist=off contest.uninstall=1
        initrd /${CONTEST_DIR}/initrd.img
    }

else

    menuentry "${install_persistent_title}" {
        linux /${CONTEST_DIR}/vmlinuz quiet splash contest_dir=/${CONTEST_DIR} contest_root=${ROOT_SQUASH_NAME} contest_persist=off
        initrd /${CONTEST_DIR}/initrd.img
    }

fi
EOF_ISO
)"

assert_file_equals "${expected_runtime_grub}" "${runtime_grub}" "runtime grub-entry.cfg"
assert_file_equals "${expected_iso_grub}" "${iso_grub}" "ISO grub.cfg"

echo "PASS: GRUB config generation matches the expected menu entries."
