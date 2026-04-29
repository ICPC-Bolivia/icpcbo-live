#!/usr/bin/env bash

set -euo pipefail

echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME}
::1 localhost ip6-localhost ip6-loopback
HOSTS

grep -q "^${LOCALE}" /etc/locale.gen || echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG="${LOCALE}"

ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
echo "${TIMEZONE}" > /etc/timezone

# Distribución de teclado para consola y X11
# (leída por keyboard-setup.service durante el arranque)
cat > /etc/default/keyboard <<KEYBOARD_EOF
XKBMODEL="pc105"
XKBLAYOUT="${KEYBOARD_LAYOUT}"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KEYBOARD_EOF
