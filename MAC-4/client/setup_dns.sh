#!/usr/bin/env bash
# ==============================================================================
# Task B: Configure Mac 4 DNS Resolver to point to Mac 1 (Private DNS Server)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../network/team_ips.env" ]; then
  source "$SCRIPT_DIR/../network/team_ips.env"
fi

INTERFACE="Wi-Fi"

echo "=========================================================="
echo "          TASK B: CONFIGURE MAC 4 DNS RESOLVER"
echo "=========================================================="

echo "Mac 4 acts as a Test Client in addition to Backend Server B."
echo "To resolve .test domains, Mac 4 must query Mac 1's DNS server."
echo ""
echo "Options:"
echo "  1) Set DNS Server to Mac 1 IP ($MAC1_DNS_IP)"
echo "  2) Set DNS Server to custom IP"
echo "  3) Reset DNS Server to Automatic (DHCP / Router default)"
echo "  4) Show Current DNS Configuration"
echo ""

read -p "Select an option [1-4]: " choice

case "$choice" in
  1)
    if [[ "$MAC1_DNS_IP" == *"X"* ]] || [ -z "$MAC1_DNS_IP" ]; then
      read -p "Enter Mac 1's actual IP address: " TARGET_IP
    else
      TARGET_IP="$MAC1_DNS_IP"
    fi
    echo "Configuring DNS on '$INTERFACE' -> $TARGET_IP (Requires sudo)..."
    sudo networksetup -setdnsservers "$INTERFACE" "$TARGET_IP"
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    echo "DNS set to $TARGET_IP and cache flushed!"
    ;;
  2)
    read -p "Enter custom DNS Server IP: " TARGET_IP
    echo "Configuring DNS on '$INTERFACE' -> $TARGET_IP (Requires sudo)..."
    sudo networksetup -setdnsservers "$INTERFACE" "$TARGET_IP"
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    echo "DNS set to $TARGET_IP and cache flushed!"
    ;;
  3)
    echo "Resetting DNS on '$INTERFACE' to DHCP default..."
    sudo networksetup -setdnsservers "$INTERFACE" "Empty"
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    echo "DNS reset to default!"
    ;;
  4)
    echo "Current DNS servers on '$INTERFACE':"
    networksetup -getdnsservers "$INTERFACE"
    echo ""
    echo "System resolver configuration (/etc/resolv.conf):"
    cat /etc/resolv.conf
    ;;
  *)
    echo "Invalid option."
    ;;
esac
