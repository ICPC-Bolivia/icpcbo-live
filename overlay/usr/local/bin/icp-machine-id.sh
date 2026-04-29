#!/usr/bin/env bash

set -euo pipefail

if [[ -f /etc/machine-id ]]; then
    cat /etc/machine-id
else
    echo "unknown"
fi
