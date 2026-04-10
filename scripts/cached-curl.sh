#!/usr/bin/env bash
# cached-curl.sh <url> <output-file>
#
# Wrapper that persists downloads to $DOWNLOAD_CACHE_DIR.
# On cache hit, copies from cache instead of re-downloading.
# Falls back to direct download if the cache dir is not available/writable.
#
# Uses the fastest available download tool:
#   axel (multi-connection) > aria2c (multi-connection) > wget > curl

set -euo pipefail

url="${1:?Usage: cached-curl.sh <url> <output-file>}"
output="${2:?Usage: cached-curl.sh <url> <output-file>}"
cache_dir="${DOWNLOAD_CACHE_DIR:-/work/download-cache}"
# Number of parallel connections for axel/aria2c (override via env)
connections="${DOWNLOAD_CONNECTIONS:-8}"

# Stable cache key: first 16 hex chars of URL sha256 + sanitised URL basename.
url_hash="$(printf '%s' "${url}" | sha256sum | cut -c1-16)"
url_base="$(basename "${url%%\?*}" | tr -cs 'a-zA-Z0-9._-' '_' | cut -c1-80)"
cache_file="${cache_dir}/${url_hash}-${url_base}"

_download() {
    local _url="$1" _dest="$2"
    if command -v axel &>/dev/null; then
        axel -n "${connections}" -q -o "${_dest}" "${_url}"
    elif command -v aria2c &>/dev/null; then
        aria2c -x "${connections}" -s "${connections}" --quiet \
            --allow-overwrite=true -o "${_dest}" "${_url}"
    elif command -v wget2 &>/dev/null; then
        wget2 --quiet -O "${_dest}" "${_url}"
    elif command -v wget &>/dev/null; then
        wget -q -O "${_dest}" "${_url}"
    else
        curl -fsSL "${_url}" -o "${_dest}"
    fi
}

if [ -d "${cache_dir}" ] && [ -w "${cache_dir}" ]; then
    if [ -f "${cache_file}" ]; then
        echo "I: [download cache] hit  : ${url}" >&2
        cp "${cache_file}" "${output}"
    else
        echo "I: [download cache] miss : ${url}" >&2
        if _download "${url}" "${cache_file}.tmp"; then
            mv "${cache_file}.tmp" "${cache_file}"
            cp "${cache_file}" "${output}"
        else
            rm -f "${cache_file}.tmp"
            exit 1
        fi
    fi
else
    echo "W: [download cache] not available at '${cache_dir}', downloading directly" >&2
    _download "${url}" "${output}"
fi
