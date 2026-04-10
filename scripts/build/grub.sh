#!/usr/bin/env bash

set -euo pipefail

grub_runtime_dir() {
    printf '/%s\n' "${CONTEST_DIR}"
}

grub_kernel_path() {
    printf '%s/vmlinuz\n' "$(grub_runtime_dir)"
}

grub_initrd_path() {
    printf '%s/initrd.img\n' "$(grub_runtime_dir)"
}

grub_linux_line() {
    local persist_mode="$1"
    local splash_mode="$2"
    shift 2

    local extra_args=("$@")

    printf 'linux %s quiet' "$(grub_kernel_path)"
    if [[ "${splash_mode}" == "splash" ]]; then
        printf ' splash'
    fi
    printf ' contest_dir=%s contest_root=%s contest_persist=%s' \
        "$(grub_runtime_dir)" \
        "${ROOT_SQUASH_NAME}" \
        "${persist_mode}"

    local arg
    for arg in "${extra_args[@]}"; do
        printf ' %s' "${arg}"
    done

    printf '\n'
}

append_grub_menuentry() {
    local file="$1"
    local title="$2"
    local root_mode="$3"
    local persist_mode="$4"
    local splash_mode="$5"
    shift 5

    {
        printf '    menuentry "%s" {\n' "${title}"

        if [[ "${root_mode}" == "hdd" ]]; then
            echo '        set root=(${hdd_root})'
        fi

        printf '        '
        grub_linux_line "${persist_mode}" "${splash_mode}" "$@"
        printf '        initrd %s\n' "$(grub_initrd_path)"
        echo '    }'
        echo
    } >> "${file}"
}

write_runtime_grub_entry() {
    local file="$1"

    {
        printf 'menuentry "%s (folder mode)" {\n' "${ISO_NAME}"
        printf '    '
        grub_linux_line "auto" "splash"
        printf '    initrd %s\n' "$(grub_initrd_path)"
        echo '}'
    } > "${file}"
}

write_iso_grub_cfg() {
    local file="$1"
    local boot_persistent_title="${ISO_NAME} - Iniciar el sistema persistente en disco"
    local install_persistent_title="${ISO_NAME} - Instalar el sistema persistente en disco"
    local clean_home_title="${ISO_NAME} - Limpiar el home de icpcbo"
    local uninstall_title="${ISO_NAME} - Eliminar los archivos instalados de icpcbo"

    cat > "${file}" <<EOF
set default=0
set timeout=30
set timeout_style=menu

# Detect an already-deployed runtime on any local partition.
# The marker is only written by deploy.sh — never present on the ISO itself.
echo "Buscando instalacion en disco local..."
search --no-floppy --set=hdd_root --file $(grub_runtime_dir)/.contest-installed

if [ -n "\${hdd_root}" ]; then

    # ── Operacion principal ───────────────────────────────────────────────
EOF

    append_grub_menuentry \
        "${file}" \
        "${boot_persistent_title}" \
        "hdd" \
        "on" \
        "splash"

    cat >> "${file}" <<'EOF'
    # ── Mantenimiento ──────────────────────────────────────────────────────
EOF

    append_grub_menuentry \
        "${file}" \
        "${clean_home_title}" \
        "hdd" \
        "on" \
        "plain" \
        "contest.clean_home=1"

    append_grub_menuentry \
        "${file}" \
        "${uninstall_title}" \
        "hdd" \
        "off" \
        "plain" \
        "contest.uninstall=1"

    cat >> "${file}" <<EOF
else

EOF

    append_grub_menuentry \
        "${file}" \
        "${install_persistent_title}" \
        "iso" \
        "off" \
        "splash"

    echo 'fi' >> "${file}"
}
