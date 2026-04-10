#!/usr/bin/env bash
# Prepares the lab deployment services that run in the live system.
# - contest-deploy.service    : auto-copies contest files to HDD on first ISO boot
# - contest-uninstall.service : triggered by 'contest.uninstall=1' kernel param
# - contest-clean-home.service: triggered by 'contest.clean_home=1' kernel param

set -euo pipefail

systemctl enable contest-deploy.service
systemctl enable contest-uninstall.service
systemctl enable contest-clean-home.service
