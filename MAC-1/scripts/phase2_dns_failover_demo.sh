#!/bin/bash
# ==============================================================================
# Script: phase2_dns_failover_demo.sh
# Purpose: Extension A - Primary DNS Failure & Recovery Controller
# Computer Networks Course Project - Phase 2 Extension A
# ==============================================================================

# Team IPs come from the single source of truth: <repo>/team.env
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/team.env"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAC1_DIR="$(dirname "$SCRIPT_DIR")"
DNSMASQ_CONF="$MAC1_DIR/configs/dnsmasq.conf"

echo "=================================================="
echo " Mac 1: Primary DNS Service Controller (Phase 2)"
echo " Role: Primary DNS Resolver for app.team1.test"
echo "=================================================="

case "${1:-status}" in
    stop)
        echo "Stopping Primary DNS (dnsmasq) to simulate DNS outage..."
        sudo pkill -f dnsmasq || true
        echo "  [DONE] Primary DNS stopped! Client queries will now failover to Mac 3 (${MAC3_IP})."
        ;;
    start)
        echo "Starting Primary DNS (dnsmasq) with config: $DNSMASQ_CONF..."
        sudo sh -c "pkill -f dnsmasq 2>/dev/null; sleep 1; /opt/homebrew/sbin/dnsmasq --conf-file=$DNSMASQ_CONF"
        echo "  [DONE] Primary DNS is RUNNING on port 53."
        ;;
    status)
        if pgrep -f dnsmasq > /dev/null; then
            echo "Primary DNS (dnsmasq) is RUNNING (PID: $(pgrep -f dnsmasq | head -n 1))"
            sudo lsof -i :53 -nP 2>/dev/null || true
        else
            echo "Primary DNS (dnsmasq) is STOPPED."
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
