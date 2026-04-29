#!/usr/bin/env bash

set -euo pipefail

CPU_LOAD="$(awk '{print $1}' /proc/loadavg)"
MEM_TOTAL="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
MEM_FREE="$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)"

cat <<EOF
{
  "cpu_load": "${CPU_LOAD}",
  "mem_used": "$((MEM_TOTAL - MEM_FREE))",
  "mem_total": "${MEM_TOTAL}"
}
EOF
