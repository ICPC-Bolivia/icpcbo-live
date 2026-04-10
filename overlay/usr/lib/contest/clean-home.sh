#!/usr/bin/env bash
# Resets the contest user's home directory to a clean state.
#
# Triggered by contest-clean-home.service when booting with contest.clean_home=1.
# Removes all user data from the persistent overlay and restores /etc/skel.
# Reboots when done so the user logs in fresh.

set -euo pipefail

LOG="/var/log/contest-clean-home.log"

_log() {
    local ts
    ts=$(date -u +%H:%M:%S)
    echo "[${ts}] $*" | tee -a "${LOG}"
    echo "[${ts}] contest-clean-home: $*" > /dev/console || true
}
_die() { _log "FATAL: $*"; exit 1; }

mkdir -p "$(dirname "${LOG}")"
[ "$(id -u)" -eq 0 ] || _die "Debe ejecutarse como root"

# Find the contest user: first non-system user with a /home directory.
CONTEST_USER="$(awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ "^/home/" {print $1; exit}' /etc/passwd)"
CONTEST_USER="${CONTEST_USER:-icpc}"
USER_HOME="/home/${CONTEST_USER}"

_log "=========================================="
_log " LIMPIAR HOME: ${USER_HOME}"
_log "=========================================="
_log "Se eliminará todo el contenido de '${USER_HOME}'."
_log "Reinicie AHORA para cancelar (10 segundos)."
sleep 10
_log "Procediendo con la limpieza..."

id -u "${CONTEST_USER}" >/dev/null 2>&1 || \
    _die "El usuario '${CONTEST_USER}' no existe en el sistema."

_log "Eliminando ${USER_HOME} ..."
rm -rf "${USER_HOME}"

_log "Restaurando desde /etc/skel ..."
cp -a /etc/skel "${USER_HOME}"
chown -R "${CONTEST_USER}:${CONTEST_USER}" "${USER_HOME}"
chmod 750 "${USER_HOME}"

_log "Home limpiado correctamente."
_log "Reiniciando en 5 segundos..."
sleep 5
reboot
