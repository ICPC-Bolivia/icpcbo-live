#!/usr/bin/env bash

set -euo pipefail

# Lee los paquetes a eliminar línea por línea para evitar separación
# incorrecta de palabras dentro de la lista.
REMOVE_PKGS=()
while IFS= read -r pkg; do
    case "${pkg}" in
        ""|\#*)
            continue
            ;;
    esac
    REMOVE_PKGS+=("${pkg}")
done < /tmp/packages-remove.list

if [ "${#REMOVE_PKGS[@]}" -gt 0 ]; then
    apt-get purge -y "${REMOVE_PKGS[@]}" || true
fi

apt-get autoremove -y --purge || true

rm -f /etc/apt/apt.conf.d/01proxy || true
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/log/*
rm -rf /tmp/* /var/tmp/*
