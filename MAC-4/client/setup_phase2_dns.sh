#!/bin/bash
# ==============================================================================
# Script: setup_phase2_dns.sh
# Purpose: Configure Mac 4 with Primary and Backup Team DNS Servers (Extension A)
# Computer Networks Course Project - Phase 2
# ==============================================================================

set -euo pipefail

PRIMARY_DNS="10.7.21.249"  # Mac 1 (Primary dnsmasq)
BACKUP_DNS="10.7.22.2"     # Mac 3 (Secondary dnsmasq)

echo "=================================================="
echo " Phase 2 DNS Configuration: Multi-Resolver Setup"
echo " Primary DNS: $PRIMARY_DNS (Mac 1)"
echo " Backup DNS : $BACKUP_DNS (Mac 3)"
echo "=================================================="

# Find active network service (typically Wi-Fi)
SERVICE=$(networksetup -listallnetworkservices | grep -E "Wi-Fi|Ethernet" | head -n 1 || echo "Wi-Fi")

echo "Active Network Service: $SERVICE"
echo "Setting DNS servers to: $PRIMARY_DNS $BACKUP_DNS"

sudo networksetup -setdnsservers "$SERVICE" "$PRIMARY_DNS" "$BACKUP_DNS"

echo ""
echo "Verifying configured DNS servers on $SERVICE:"
networksetup -getdnsservers "$SERVICE"

echo ""
echo "Flushing local macOS DNS cache..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo ""
echo "Testing resolution of app.team1.test..."
dig +short app.team1.test

echo ""
echo "=================================================="
echo " Phase 2 Multi-Resolver DNS configured successfully!"
echo "=================================================="
