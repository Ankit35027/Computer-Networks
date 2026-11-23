#!/bin/bash
# Superseded: Extension C now uses <repo>/scripts/pf_isolation.sh (anchor-based,
# never replaces /etc/pf.conf). This wrapper only forwards to it.
# Backends live on Mac 3 (3001) and Mac 4 (3002) - run it THERE, not on Mac 2.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/pf_isolation.sh" "$@"
