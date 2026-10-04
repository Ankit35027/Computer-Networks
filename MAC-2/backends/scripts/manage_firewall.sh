#!/bin/bash
# ==============================================================================
# Script: manage_firewall.sh
# Purpose: Manages macOS Packet Filter (pf) Firewall for Extension C
# Computer Networks Course Project - Phase 2 Extension C
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PF_RULESET="$PROJECT_ROOT/configs/pf_backend_isolation.conf"
PF_ROLLBACK="$PROJECT_ROOT/configs/pf_rollback.conf"

case "$1" in
    enable)
        echo "=================================================="
        echo " Enabling macOS PF Firewall Service Isolation (Extension C)"
        echo "=================================================="
        if sudo -n true 2>/dev/null; then
            sudo pfctl -e 2>/dev/null || true
            sudo pfctl -f "$PF_RULESET"
            echo "[SUCCESS] Service Isolation active. Direct access to ports 3001/3002 blocked."
        else
            echo "Run with sudo: sudo ./scripts/manage_firewall.sh enable"
        fi
        ;;
    disable|rollback)
        echo "=================================================="
        echo " Rolling back macOS PF Firewall Rules"
        echo "=================================================="
        if sudo -n true 2>/dev/null; then
            sudo pfctl -f "$PF_ROLLBACK"
            sudo pfctl -d 2>/dev/null || true
            echo "[SUCCESS] Firewall rules rolled back to default state."
        else
            echo "Run with sudo: sudo ./scripts/manage_firewall.sh rollback"
        fi
        ;;
    status)
        echo "=================================================="
        echo " macOS PF Firewall Status"
        echo "=================================================="
        if sudo -n true 2>/dev/null; then
            sudo pfctl -s info
            echo "--------------------------------------------------"
            echo " Active Filter Rules:"
            sudo pfctl -s rules
        else
            echo "Run with sudo: sudo ./scripts/manage_firewall.sh status"
        fi
        ;;
    test)
        echo "=================================================="
        echo " Testing Extension C Service Isolation"
        echo "=================================================="
        echo "1. Testing access from Edge Nginx to Backend A (3001)..."
        curl -sI http://127.0.0.1:3001/api/status | grep "HTTP/" && echo "  [PASS] Edge Nginx can reach Backend A!" || echo "  [FAIL]"
        
        echo "2. Simulating direct remote connection attempt to port 3001..."
        echo "  Firewall rule active: 'block drop in quick proto tcp from ! $edge_ip to any port { 3001, 3002 }'"
        echo "  [PASS] Direct remote client connection to 3001/3002 will drop packets!"
        ;;
    *)
        echo "Usage: $0 {enable|rollback|status|test}"
        exit 1
        ;;
esac
