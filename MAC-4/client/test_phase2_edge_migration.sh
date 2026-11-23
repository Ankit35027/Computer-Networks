#!/bin/bash
# ==============================================================================
# Script: test_phase2_edge_migration.sh
# Purpose: Extension E - Verify Controlled Edge Migration (DNS Cutover)
# Computer Networks Course Project - Phase 2 Extension E
# ==============================================================================

# Team IPs come from the single source of truth: <repo>/team.env
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/team.env"

DOMAIN="app.team1.test"
PRIMARY_EDGE_IP="${MAC2_IP}"
STANDBY_EDGE_IP="${MAC3_IP}"

echo "=================================================="
echo " Extension E: Controlled Edge Migration Verification"
echo " Primary Edge Proxy : $PRIMARY_EDGE_IP (Mac 2)"
echo " Standby Edge Proxy : $STANDBY_EDGE_IP (Mac 3)"
echo "=================================================="

echo ""
echo "[STEP 1] Current DNS Resolution for $DOMAIN..."
RESOLVED_IP=$(dig +short "$DOMAIN" | head -n 1)
echo "  Resolved Edge IP: ${RESOLVED_IP:-Not resolved}"

if [ "$RESOLVED_IP" == "$PRIMARY_EDGE_IP" ]; then
    echo "  -> Target is currently PRIMARY Edge (Mac 2)."
elif [ "$RESOLVED_IP" == "$STANDBY_EDGE_IP" ]; then
    echo "  -> Target has CUT OVER to STANDBY Edge (Mac 3)!"
fi

echo ""
echo "[STEP 2] End-to-End HTTPS Health via Currently Resolved Edge..."
RESP=$(curl -skI "https://$DOMAIN:8443/api/status" 2>/dev/null || echo "")
HTTP_STATUS=$(echo "$RESP" | grep "HTTP/" | head -n 1)
SERVER_HEADER=$(echo "$RESP" | grep -i "server:" | tr -d '\r')

echo "  Status : ${HTTP_STATUS:-No response}"
echo "  Server : ${SERVER_HEADER:-Unknown}"

echo ""
echo "=================================================="
echo " Edge Migration Cutover Instructions:"
echo " 1. On Mac 1 / Mac 3 dnsmasq: set address=/app.team1.test/$STANDBY_EDGE_IP"
echo " 2. Reload DNS: sudo pkill -HUP dnsmasq"
echo " 3. On Client: flush cache (sudo dscacheutil -flushcache)"
echo " 4. Re-run this script to confirm traffic now reaches Standby Edge!"
echo "=================================================="
