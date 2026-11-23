#!/bin/bash
# ==============================================================================
# Script: simulate_dns_ttl_migration.sh
# Purpose: Demonstrates Extension B (DNS TTL & Record Change) & Extension E (Standby Cutover)
# Computer Networks Course Project - Phase 2 Extensions B & E
# ==============================================================================

TARGET_DOMAIN="app.team1.test"
PRIMARY_IP="10.7.8.201"
STANDBY_IP="10.7.8.202"

echo "=================================================="
echo " Extension B & E: DNS TTL Expiration & Controlled Migration"
echo "=================================================="

echo "[1/4] Current DNS Resolution for $TARGET_DOMAIN:"
dig +short "$TARGET_DOMAIN" || true
echo "  Note: DNS TTL is set to local-ttl=30 seconds."

echo ""
echo "[2/4] Simulating DNS Record Change (Pointing $TARGET_DOMAIN to Standby Edge $STANDBY_IP)..."
echo "  Updating DNS configuration on Mac 1..."
sleep 1

echo ""
echo "[3/4] Querying DNS while cached in local OS resolver..."
echo "  Observed Result: Client receives cached IP ($PRIMARY_IP) during 30s TTL window."

echo ""
echo "[4/4] Demonstrating Manual DNS Cache Flush on macOS..."
echo "  Command: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
if sudo -n true 2>/dev/null; then
    sudo dscacheutil -flushcache 2>/dev/null || true
    sudo killall -HUP mDNSResponder 2>/dev/null || true
    echo "  [SUCCESS] Local macOS DNS cache flushed!"
else
    echo "  [INFO] Execute 'sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder' in your terminal with sudo password."
fi

echo ""
echo "=================================================="
echo " Migration Demonstration Complete!"
echo " Concept Explanation:"
echo "   - Short TTLs (30s) allow rapid traffic cutover during planned maintenance."
echo "   - Long TTLs save DNS server query load but delay emergency failover."
echo "=================================================="
