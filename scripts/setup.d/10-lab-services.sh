#!/usr/bin/env bash
# Prepara los servicios de despliegue del laboratorio que corren en el sistema en vivo.
# - contest-full-install.service : instalación completa a disco
#   (unsquashfs + GRUB) con contest.install_mode=full
# - contest-deploy.service       : instalación por overlay
#   (copia del squashfs) en el primer arranque del ISO

set -euo pipefail

systemctl enable contest-full-install.service
systemctl enable contest-deploy.service
systemctl enable contest-overlay-provision.service
systemctl enable contest-update.service
systemctl enable stats-report.timer
