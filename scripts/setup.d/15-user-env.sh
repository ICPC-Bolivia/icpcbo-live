#!/usr/bin/env bash

set -euo pipefail

DEFAULT_USER_VAL="${DEFAULT_USER}"
OPT_DIR="${OPT_CONTEST_DIR}"

# ----------------------------------------------------------------
# Configuración de /etc/skel
# aplicada al directorio personal del usuario por build.sh después de los hooks
# ----------------------------------------------------------------

mkdir -p /etc/skel/.config

# Omitir el asistente inicial de GNOME para usuarios nuevos
echo yes > /etc/skel/.config/gnome-initial-setup-done

# Configuración por defecto de VS Code
mkdir -p /etc/skel/.config/Code/User
cat > /etc/skel/.config/Code/User/settings.json <<'EOM'
{
    "C_Cpp.default.cppStandard": "gnu++20",
    "editor.fontSize": 14,
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "terminal.integrated.fontSize": 13
}
EOM

# Accesos directos del escritorio
mkdir -p /etc/skel/Desktop
if [ -f "${OPT_DIR}/misc/icpcbo.desktop" ]; then
    cp "${OPT_DIR}/misc/icpcbo.desktop" /etc/skel/Desktop/
    chmod +x /etc/skel/Desktop/icpcbo.desktop
fi
if [ -f /usr/share/applications/gnome-keyboard-panel.desktop ]; then
    cp /usr/share/applications/gnome-keyboard-panel.desktop /etc/skel/Desktop/
    chmod +x /etc/skel/Desktop/gnome-keyboard-panel.desktop
fi

# Agregar herramientas del concurso al PATH y definir alias
cat >> /etc/skel/.bashrc <<EOF

# Herramientas del concurso ICPC Bolivia
export PATH="\${PATH}:${OPT_DIR}/bin"
alias icpcboconf='sudo ${OPT_DIR}/bin/icpcboconf.sh'
alias icpcbobackup='sudo ${OPT_DIR}/bin/icpcbobackup.sh'
EOF

# ----------------------------------------------------------------
# Variable PATH global del sistema para todos los usuarios
# ----------------------------------------------------------------
cat > /etc/profile.d/icpc.sh <<EOF
export PATH="\${PATH}:${OPT_DIR}/bin"
EOF

# ----------------------------------------------------------------
# Entrada de autoarranque de GNOME
# ----------------------------------------------------------------
if [ -f "${OPT_DIR}/misc/icpcbostart.desktop" ]; then
    mkdir -p /usr/share/gnome/autostart
    cp "${OPT_DIR}/misc/icpcbostart.desktop" /usr/share/gnome/autostart/
fi

# ----------------------------------------------------------------
# Sudoers: permitir que el usuario concursante ejecute
# herramientas del concurso como root
# ----------------------------------------------------------------
cat > /etc/sudoers.d/icpc <<SUDO
${DEFAULT_USER_VAL} ALL=(root) NOPASSWD: ${OPT_DIR}/bin/icpcboconf.sh
${DEFAULT_USER_VAL} ALL=(root) NOPASSWD: ${OPT_DIR}/bin/icpcbobackup.sh
${DEFAULT_USER_VAL} ALL=(root) NOPASSWD: ${OPT_DIR}/sbin/contest.sh
SUDO
chmod 440 /etc/sudoers.d/icpc

# ----------------------------------------------------------------
# Aplicar directamente al usuario que ya existe dentro del chroot
# (build.sh copiará luego skel y sobrescribirá estos archivos;
#  escribir aquí asegura el resultado correcto incluso si cambia
#  la lógica de skel)
# ----------------------------------------------------------------
if id -u "${DEFAULT_USER_VAL}" >/dev/null 2>&1; then
    user_home="$(getent passwd "${DEFAULT_USER_VAL}" | cut -d: -f6)"

    mkdir -p "${user_home}/.config/Code/User"
    cp /etc/skel/.config/Code/User/settings.json "${user_home}/.config/Code/User/"

    mkdir -p "${user_home}/Desktop"
    [ -f "${OPT_DIR}/misc/icpcbo.desktop" ] && \
        cp "${OPT_DIR}/misc/icpcbo.desktop" "${user_home}/Desktop/" && \
        chmod +x "${user_home}/Desktop/icpcbo.desktop"
    [ -f /usr/share/applications/gnome-keyboard-panel.desktop ] && \
        cp /usr/share/applications/gnome-keyboard-panel.desktop "${user_home}/Desktop/" && \
        chmod +x "${user_home}/Desktop/gnome-keyboard-panel.desktop"

    chown -R "${DEFAULT_USER_VAL}:${DEFAULT_USER_VAL}" \
        "${user_home}/.config" "${user_home}/Desktop" 2>/dev/null || true
fi
