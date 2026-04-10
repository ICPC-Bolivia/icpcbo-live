#!/usr/bin/env bash

normalize_contest_dir() {
    local dir="${1:-/contest}"

    case "${dir}" in
        /*) printf '%s\n' "${dir}" ;;
        *) printf '/%s\n' "${dir}" ;;
    esac
}

cmdline_param() {
    local key="${1:?missing kernel cmdline key}"

    tr ' ' '\n' < /proc/cmdline | grep -m1 "^${key}=" | cut -d= -f2- || true
}

mount_opts_for_fstype() {
    local fstype="${1:?missing filesystem type}"
    local mode="${2:?missing mount mode}"

    case "${fstype}" in
        ntfs|ntfs3) printf '%s,nls=utf8\n' "${mode}" ;;
        *) printf '%s\n' "${mode}" ;;
    esac
}

overlay_storage_mb_for_fstype() {
    local fstype="${1:?missing filesystem type}"
    local overlay_img_size_mb="${2:?missing overlay image size}"

    case "${fstype}" in
        ext4|ext3|xfs) printf '0\n' ;;
        *) printf '%s\n' "${overlay_img_size_mb}" ;;
    esac
}

read_install_marker() {
    local marker_file="${1:?missing marker file}"
    local key value

    MARKER_INSTALLED_DATE=""
    MARKER_TARGET_DEV=""
    MARKER_TARGET_FSTYPE=""
    MARKER_OVERLAY_IMG_CREATED=""
    MARKER_CONTEST_DIR=""
    MARKER_CONTEST_ROOT=""
    MARKER_EFI_BOOT_NUM=""

    while IFS='=' read -r key value; do
        case "${key}" in
            INSTALLED_DATE) MARKER_INSTALLED_DATE="${value}" ;;
            TARGET_DEV) MARKER_TARGET_DEV="${value}" ;;
            TARGET_FSTYPE) MARKER_TARGET_FSTYPE="${value}" ;;
            OVERLAY_IMG_CREATED) MARKER_OVERLAY_IMG_CREATED="${value}" ;;
            CONTEST_DIR) MARKER_CONTEST_DIR="${value}" ;;
            CONTEST_ROOT) MARKER_CONTEST_ROOT="${value}" ;;
            EFI_BOOT_NUM) MARKER_EFI_BOOT_NUM="${value}" ;;
            *) ;;
        esac
    done < "${marker_file}"
}
