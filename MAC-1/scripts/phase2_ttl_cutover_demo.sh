#!/bin/bash
# ==============================================================================
# Script: phase2_ttl_cutover_demo.sh
# Purpose: Extension B & E - DNS Record Cutover & Invalidation Simulator on Mac 1
# Computer Networks Course Project - Phase 2
# ==============================================================================

# Team IPs come from the single source of truth: <repo>/team.env
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/team.env"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAC1_DIR="$(dirname "$SCRIPT_DIR")"
DNSMASQ_CONF="$MAC1_DIR/configs/dnsmasq.conf"

PRIMARY_EDGE_IP="${MAC2_IP}"
STANDBY_EDGE_IP="${MAC3_IP}"

echo "=================================================="
echo " Mac 1: DNS Record Cutover Simulator (Extensions B & E)"
echo " Controls mapping for app.team1.test"
echo "=================================================="

case "${1:-status}" in
    cutover-standby)
        echo "Updating app.team1.test to point to STANDBY Edge (Mac 3: $STANDBY_EDGE_IP)..."
        sed -i '' "s|address=/app.team1.test/.*|address=/app.team1.test/$STANDBY_EDGE_IP|g" "$DNSMASQ_CONF"
        echo "Restarting dnsmasq (SIGHUP does not reload address= records)..."
        sudo pkill -x dnsmasq 2>/dev/null; sleep 1; sudo /opt/homebrew/sbin/dnsmasq --conf-file="$DNSMASQ_CONF"
        echo "  [DONE] Record updated! Query result:"
        dig @127.0.0.1 +short app.team1.test
        ;;
    restore-primary)
        echo "Restoring app.team1.test to point to PRIMARY Edge (Mac 2: $PRIMARY_EDGE_IP)..."
        sed -i '' "s|address=/app.team1.test/.*|address=/app.team1.test/$PRIMARY_EDGE_IP|g" "$DNSMASQ_CONF"
        echo "Restarting dnsmasq (SIGHUP does not reload address= records)..."
        sudo pkill -x dnsmasq 2>/dev/null; sleep 1; sudo /opt/homebrew/sbin/dnsmasq --conf-file="$DNSMASQ_CONF"
        echo "  [DONE] Record restored! Query result:"
        dig @127.0.0.1 +short app.team1.test
        ;;
    status)
        echo "Current configuration in $DNSMASQ_CONF:"
        grep -E "address=/app.team1.test|local-ttl" "$DNSMASQ_CONF"
        echo ""
        echo "Active dig response:"
        dig @127.0.0.1 app.team1.test +noall +answer
        ;;
    *)
        echo "Usage: $0 {cutover-standby|restore-primary|status}"
        exit 1
        ;;
esac
