#!/usr/bin/env bash
# ==============================================================================
# Task A: Network Inventory for Mac 4
# Gathers: IPv4 address, Subnet mask, Default Gateway, Interface, MAC address
# ==============================================================================

echo "=========================================================="
echo "          MAC 4 (Backend B + Test Client) NETWORK INFO"
echo "=========================================================="

INTERFACE=$(route -n get default 2>/dev/null | grep 'interface:' | awk '{print $2}')
if [ -z "$INTERFACE" ]; then
  INTERFACE="en0"
fi

IPV4=$(ipconfig getifaddr "$INTERFACE" 2>/dev/null)
NETMASK=$(ipconfig getoption "$INTERFACE" subnet_mask 2>/dev/null)
GATEWAY=$(route -n get default 2>/dev/null | grep 'gateway:' | awk '{print $2}')
MAC_ADDR=$(ifconfig "$INTERFACE" 2>/dev/null | grep 'ether' | awk '{print $2}')
HOSTNAME=$(hostname)

echo "Hostname        : $HOSTNAME"
echo "Role            : Backend Server B (Port 3002) + Test Client"
echo "Active Interface: $INTERFACE"
echo "IPv4 Address    : $IPV4"
echo "Subnet Mask     : $NETMASK"
echo "Default Gateway : $GATEWAY"
echo "MAC Address     : $MAC_ADDR"
echo "=========================================================="
echo ""
echo "Share these exact values with your team for the Task A Architecture Table!"
