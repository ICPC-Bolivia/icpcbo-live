#!/usr/bin/env bash
# Ejecuta todos los archivos regulares de un directorio como hooks de bash,
# ordenados por nombre de archivo.
# Uso: run-hook-dir.sh <directorio>
#
# Este script se copia dentro del chroot durante el build y es usado por
# phase_install_and_customize y phase_trim. Tenerlo aquí elimina las
# definiciones inline duplicadas dentro de build.sh.

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: run-hook-dir.sh <directory>" >&2
    exit 1
fi

dir="$1"

[ -d "${dir}" ] || exit 0

while IFS= read -r hook; do
    [ -f "${hook}" ] || continue
    echo "I: running hook ${hook}" >&2
    /bin/bash -eux "${hook}"
done < <(find "${dir}" -maxdepth 1 -type f | sort)
