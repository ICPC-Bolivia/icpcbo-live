#!/usr/bin/env bash

set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPT="${PROJECT_DIR}/scripts/build.sh"

# shellcheck source=./config/iso.conf
source "${PROJECT_DIR}/config/iso.conf"

if [[ -f "${PROJECT_DIR}/config/iso.local.conf" ]]; then
    # shellcheck source=/dev/null
    source "${PROJECT_DIR}/config/iso.local.conf"
fi

resolve_output_dir() {
    local output_dir="${OUTPUT_DIR}"

    if [[ "${output_dir}" == /work/* ]] && { [[ ! -d /work ]] || [[ ! -w /work ]]; }; then
        output_dir="${PROJECT_DIR}/output"
    fi

    if [[ -e "${output_dir}" && ! -w "${output_dir}" ]]; then
        output_dir="${PROJECT_DIR}/output-local"
    elif [[ ! -e "${output_dir}" && ! -w "$(dirname "${output_dir}")" ]]; then
        output_dir="${PROJECT_DIR}/output-local"
    fi

    printf '%s\n' "${output_dir}"
}

latest_iso_path() {
    local output_dir="${1:?missing output dir}"

    find "${output_dir}" -maxdepth 1 -type f -name '*.iso' -printf '%T@ %p\n' 2>/dev/null \
        | sort -nr \
        | head -n1 \
        | cut -d' ' -f2-
}

latest_full_iso_path() {
    local output_dir="${1:?missing output dir}"

    find "${output_dir}" -maxdepth 1 -type f -name '*.iso' ! -name '*-grub-preview.iso' -printf '%T@ %p\n' 2>/dev/null \
        | sort -nr \
        | head -n1 \
        | cut -d' ' -f2-
}

preview_iso_path() {
    local output_dir="${1:?missing output dir}"

    printf '%s/%s-grub-preview.iso\n' "${output_dir}" "${ISO_NAME}"
}

print_grub_preview_hint() {
    local output_dir="$1"
    local preview_dir="${output_dir}/grub-preview"
    local iso_grub="${preview_dir}/boot/grub/grub.cfg"
    local runtime_grub="${preview_dir}/${CONTEST_DIR}/grub-entry.cfg"
    local preview_iso

    preview_iso="$(latest_iso_path "${output_dir}")"

    if [[ -f "${iso_grub}" || -f "${runtime_grub}" ]]; then
        echo "GRUB preview detected:" >&2
        [[ -f "${iso_grub}" ]] && echo "  - ${iso_grub}" >&2
        [[ -f "${runtime_grub}" ]] && echo "  - ${runtime_grub}" >&2
        if [[ -n "${preview_iso}" && -f "${preview_iso}" ]]; then
            echo "  - ${preview_iso}" >&2
            echo "Use 'bash start.sh latest-preview' or the interactive menu to boot it." >&2
        else
            echo "Generate it with 'bash ${BUILD_SCRIPT} grub-preview' or the interactive menu." >&2
        fi
    fi
}

show_grub_preview() {
    local output_dir="$1"
    local preview_dir="${output_dir}/grub-preview"
    local iso_grub="${preview_dir}/boot/grub/grub.cfg"
    local runtime_grub="${preview_dir}/${CONTEST_DIR}/grub-entry.cfg"

    [[ -f "${iso_grub}" || -f "${runtime_grub}" ]] || {
        echo "No GRUB preview found in ${preview_dir}" >&2
        return 1
    }

    if [[ -f "${iso_grub}" ]]; then
        echo "===== ${iso_grub} ====="
        cat "${iso_grub}"
        echo
    fi

    if [[ -f "${runtime_grub}" ]]; then
        echo "===== ${runtime_grub} ====="
        cat "${runtime_grub}"
    fi
}

VM_NAME="${VM_NAME:-icpc-bolivia-debian}"
RAM_MB="${RAM_MB:-6048}"
VCPUS="${VCPUS:-2}"
DISK_SIZE_GB="${DISK_SIZE_GB:-20}"
DISK_PATH="${DISK_PATH:-/var/lib/libvirt/images/${VM_NAME}.qcow2}"
OUTPUT_DIR_RESOLVED="$(resolve_output_dir)"
ISO_PATH="${ISO_PATH:-$(latest_iso_path "${OUTPUT_DIR_RESOLVED}")}"
WIFI_HOSTDEV="${WIFI_HOSTDEV:-}"
OS_VARIANT="${OS_VARIANT:-debian13}"

# ----------------------------------------------------------------
# Lab simulation mode  (LAB_SIM=1)
#
# Simulates a lab machine with Windows/Linux on HDD + the contest ISO in the drive.
# The ISO's GRUB is the only bootloader — it auto-detects the deployment state:
#
#   First boot:    GRUB shows "Instalar el sistema persistente en disco"
#                  → deploy.sh copies files to HDD, creates overlay.img if needed
#
#   Later boots:   GRUB shows 3 options:
#                  - "Iniciar el sistema persistente en disco"  ← default
#                  - "Limpiar el home de icpcbo"
#                  - "Eliminar los archivos instalados de icpcbo"
#
# To start over (simulate a fresh machine):
#   sudo rm /var/lib/libvirt/images/icpc-bolivia-debian-lab-hdd.qcow2
#
# ----------------------------------------------------------------
LAB_SIM="${LAB_SIM:-0}"
LAB_DISK_PATH="${LAB_DISK_PATH:-/var/lib/libvirt/images/${VM_NAME}-lab-hdd.qcow2}"

launch_vm() {
    local selected_iso="${1:?missing ISO path}"
    HOSTDEV_ARGS=()
    if [[ -n "${WIFI_HOSTDEV}" ]]; then
        HOSTDEV_ARGS=(--hostdev "${WIFI_HOSTDEV}")
    fi

    # ----------------------------------------------------------------
    # Prepare lab HDD image (created once, reused across reboots)
    # ----------------------------------------------------------------
    if [[ "${LAB_SIM}" == "1" ]]; then
        if [[ ! -f "${LAB_DISK_PATH}" ]]; then
            echo "LAB_SIM: creating HDD image: ${LAB_DISK_PATH}"
            sudo qemu-img create -f qcow2 "${LAB_DISK_PATH}" "${DISK_SIZE_GB}G"

            # Partition + format as ext4 so deploy.sh finds it immediately.
            # Requires: sudo apt install libguestfs-tools
            if command -v guestfish >/dev/null 2>&1; then
                sudo guestfish -a "${LAB_DISK_PATH}" <<'GUESTFISH'
run
part-init /dev/sda mbr
part-add /dev/sda p 2048 -1
mkfs ext4 /dev/sda1
GUESTFISH
                echo "LAB_SIM: HDD partitioned and formatted (ext4 on /dev/vda1)"
            else
                echo "ERROR: guestfish not found. Install: sudo apt install libguestfs-tools" >&2
                sudo rm -f "${LAB_DISK_PATH}"
                return 1
            fi
        else
            echo "LAB_SIM: reusing HDD image: ${LAB_DISK_PATH}"
        fi
    fi

    # ----------------------------------------------------------------
    # Destroy any previous VM instance
    # ----------------------------------------------------------------
    sudo virsh destroy "${VM_NAME}" 2>/dev/null || true
    sudo virsh undefine "${VM_NAME}" 2>/dev/null || true

    # ----------------------------------------------------------------
    # Launch VM
    # ----------------------------------------------------------------
    if [[ "${LAB_SIM}" == "1" ]]; then
        # ISO always present (it's the bootloader source).
        # HDD attached as secondary disk — deploy.sh writes contest files there.
        # boot order: cdrom first so the ISO GRUB always loads.
        echo "LAB_SIM: starting VM  (ISO: $(basename "${selected_iso}")  HDD: $(basename "${LAB_DISK_PATH}"))"
        sudo virt-install \
            --connect qemu:///system \
            --name "${VM_NAME}" \
            --ram "${RAM_MB}" \
            --vcpus "${VCPUS}" \
            --disk "path=${LAB_DISK_PATH},format=qcow2,bus=virtio" \
            --os-variant "${OS_VARIANT}" \
            --cdrom "${selected_iso}" \
            --network network=default \
            --graphics spice \
            --video virtio \
            --boot cdrom,hd \
            --cpu host-model \
            "${HOSTDEV_ARGS[@]}"
    else
        # Normal mode: ephemeral disk, no HDD simulation.
        sudo rm -f "${DISK_PATH}"
        sudo virt-install \
            --connect qemu:///system \
            --name "${VM_NAME}" \
            --ram "${RAM_MB}" \
            --vcpus "${VCPUS}" \
            --disk "path=${DISK_PATH},size=${DISK_SIZE_GB},format=qcow2" \
            --os-variant "${OS_VARIANT}" \
            --cdrom "${selected_iso}" \
            --network network=default \
            --graphics spice \
            --video virtio \
            --boot cdrom,hd \
            --cpu host-model \
            "${HOSTDEV_ARGS[@]}"
    fi
}

require_iso() {
    local selected_iso="${1-}"

    if [[ -z "${selected_iso}" || ! -f "${selected_iso}" ]]; then
        echo "ISO not found. Set ISO_PATH or build one first (output is at ${OUTPUT_DIR_RESOLVED})" >&2
        print_grub_preview_hint "${OUTPUT_DIR_RESOLVED}"
        return 1
    fi
}

build_target() {
    local target="${1:?missing build target}"

    bash "${BUILD_SCRIPT}" "${target}"
}

start_usage() {
    cat <<EOF
Usage: $(basename "$0") [menu|latest|latest-full|latest-preview|build-full|build-preview|grub-preview|help]

Actions:
  menu            Show interactive start menu
  latest          Boot the newest ISO found in ${OUTPUT_DIR_RESOLVED}
  latest-full     Boot the newest full ISO (excluding grub preview ISO)
  latest-preview  Boot the GRUB preview ISO
  build-full      Build the full ISO and boot it
  build-preview   Build the GRUB preview ISO and boot it
  grub-preview    Show the generated GRUB preview files
  help            Show this help
EOF
}

run_start_action() {
    local action="${1:-latest}"
    local selected_iso=""

    case "${action}" in
        latest)
            selected_iso="${ISO_PATH:-$(latest_iso_path "${OUTPUT_DIR_RESOLVED}")}"
            require_iso "${selected_iso}"
            launch_vm "${selected_iso}"
            ;;
        latest-full)
            selected_iso="$(latest_full_iso_path "${OUTPUT_DIR_RESOLVED}")"
            require_iso "${selected_iso}"
            launch_vm "${selected_iso}"
            ;;
        latest-preview)
            selected_iso="$(preview_iso_path "${OUTPUT_DIR_RESOLVED}")"
            require_iso "${selected_iso}"
            launch_vm "${selected_iso}"
            ;;
        build-full)
            build_target full
            selected_iso="$(latest_full_iso_path "${OUTPUT_DIR_RESOLVED}")"
            require_iso "${selected_iso}"
            launch_vm "${selected_iso}"
            ;;
        build-preview)
            build_target grub-preview
            selected_iso="$(preview_iso_path "${OUTPUT_DIR_RESOLVED}")"
            require_iso "${selected_iso}"
            launch_vm "${selected_iso}"
            ;;
        grub-preview)
            show_grub_preview "${OUTPUT_DIR_RESOLVED}"
            ;;
        menu)
            start_interactive_menu
            ;;
        help|-h|--help)
            start_usage
            ;;
        *)
            echo "Unknown start action: ${action}" >&2
            start_usage >&2
            return 1
            ;;
    esac
}

start_interactive_menu() {
    while true; do
        cat <<'EOF'

========================================
 Start Menu
========================================
1) Levantar último ISO disponible
2) Generar build completo y levantar ISO
3) Levantar ISO preview de GRUB
4) Generar solo GRUB y levantar ISO preview
5) Ver archivos GRUB preview
6) Salir
EOF

        read -r -p "Selecciona una opción [1-6]: " option
        echo

        case "${option}" in
            1)
                run_start_action latest
                return 0
                ;;
            2)
                run_start_action build-full
                return 0
                ;;
            3)
                run_start_action latest-preview
                return 0
                ;;
            4)
                run_start_action build-preview
                return 0
                ;;
            5)
                run_start_action grub-preview
                echo
                read -r -p "Presiona Enter para volver al menú..." _
                ;;
            6)
                return 0
                ;;
            *)
                echo "Opción inválida."
                echo
                ;;
        esac
    done
}

main() {
    local action="${1-}"

    if [[ -z "${action}" ]]; then
        if [[ -t 0 && -t 1 ]]; then
            start_interactive_menu
        else
            run_start_action latest
        fi
        return 0
    fi

    run_start_action "${action}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
