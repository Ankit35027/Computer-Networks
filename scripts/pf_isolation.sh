#!/bin/bash
# ==============================================================================
# pf_isolation.sh – Phase 2 Extension C: Service Isolation with macOS pf
#
#   sudo ./scripts/pf_isolation.sh enable 3001   # on Mac 3 (Backend A)
#   sudo ./scripts/pf_isolation.sh enable 3002   # on Mac 4 (Backend B)
#   sudo ./scripts/pf_isolation.sh status
#   sudo ./scripts/pf_isolation.sh disable       # ROLLBACK (restores original state)
#
# Safety design:
#   * Never edits /etc/pf.conf. Rules go ONLY into the sub-anchor
#     "com.apple/cn-isolation", which the stock macOS ruleset already evaluates
#     through its  anchor "com.apple/*"  line. Flushing that anchor = rollback.
#   * pf is enabled with "pfctl -E" (reference-counted token). "disable" releases
#     only OUR token, so pf stays in whatever state macOS/other tools had it.
#   * The original ruleset + pf state are backed up before any change.
#
# Rules (IPs from <repo>/team.env – nothing hard-coded):
#   pass  : Mac 2 edge (MAC2_IP) and the standby edge on Mac 3 (MAC3_IP, Ext E)
#   pass  : loopback (local tests, standby nginx on the same Mac)
#   block : everyone else -> "block drop" = silent drop, so a client sees a
#           TIMEOUT (firewall), not "connection refused" (closed port).
# ==============================================================================
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/team.env"
ANCHOR="com.apple/cn-isolation"
STATE_DIR="/var/tmp/cn-isolation"
RULES="$STATE_DIR/rules.conf"
TOKEN_FILE="$STATE_DIR/token"

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo: sudo $0 $*"; exit 1; }
mkdir -p "$STATE_DIR"

show() {
    echo "-- pf status:";            pfctl -s info 2>/dev/null | head -1
    echo "-- rules in $ANCHOR:";     pfctl -a "$ANCHOR" -s rules 2>/dev/null || true
}

case "$1" in
  enable)
    PORT="$2"
    [[ "$PORT" =~ ^(3001|3002)$ ]] || { echo "Usage: sudo $0 enable 3001|3002"; exit 1; }

    # 1. Backup of the original state (for rollback evidence)
    BK="$STATE_DIR/backup_$(date +%Y%m%d_%H%M%S).txt"
    { echo "# pf backup before cn-isolation $(date)"; pfctl -s info 2>&1 | head -3; echo "# main rules:"; pfctl -s rules 2>&1; } > "$BK"
    echo "Backup of original pf state: $BK"

    # 2. Make sure the stock macOS ruleset (which evaluates com.apple/*) is loaded
    if ! pfctl -s rules 2>/dev/null | grep -q 'anchor "com.apple/\*"'; then
        echo "Stock ruleset not loaded -> loading unmodified /etc/pf.conf"
        pfctl -q -f /etc/pf.conf || { echo "ERROR: could not load /etc/pf.conf"; exit 1; }
    fi

    # 3. Generate the anchor rules from team.env
    cat > "$RULES" <<EOF
# cn-isolation: only the edge(s) may reach backend port $PORT on this Mac
pass  in quick on lo0 proto tcp from any to any port $PORT
pass  in quick proto tcp from { $MAC2_IP, $MAC3_IP } to any port $PORT
block drop in quick proto tcp from any to any port $PORT
EOF
    pfctl -q -a "$ANCHOR" -f "$RULES" || { echo "ERROR: pfctl rejected the rules"; exit 1; }

    # 4. Enable pf with a reference token (only if we don't already hold one)
    if [ ! -s "$TOKEN_FILE" ]; then
        pfctl -E 2>&1 | awk '/Token/ {print $NF}' > "$TOKEN_FILE"
    fi
    echo "pf enable token: $(cat "$TOKEN_FILE")"
    echo "== Extension C ENABLED: port $PORT reachable only from edge $MAC2_IP (+ standby $MAC3_IP) and localhost"
    show
    ;;

  disable|rollback)
    pfctl -q -a "$ANCHOR" -F rules 2>/dev/null
    if [ -s "$TOKEN_FILE" ]; then pfctl -X "$(cat "$TOKEN_FILE")" 2>&1 | tail -1; rm -f "$TOKEN_FILE"; fi
    echo "== Extension C ROLLED BACK: anchor flushed, our pf reference released (/etc/pf.conf never modified)"
    show
    ;;

  status)
    show ;;

  *)
    echo "Usage: sudo $0 {enable 3001|enable 3002|status|disable}"; exit 1 ;;
esac
