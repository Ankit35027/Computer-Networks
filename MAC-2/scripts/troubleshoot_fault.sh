#!/bin/bash
# Superseded by <repo>/scripts/diagnose.sh (LAN-aware, IPs from team.env, no -k,
# no silent 127.0.0.1 fallback). Run it from a CLIENT Mac (Mac 4/Mac 1).
# Runbook: docs/EXT_F_TROUBLESHOOTING_RUNBOOK.md
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/diagnose.sh" "$@"
