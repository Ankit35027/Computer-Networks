#!/bin/bash
# ==============================================================================
# Script: get_network_info.sh
# Purpose: Collects private IPv4, Subnet Mask, Gateway, Interface Name, and MAC
# Computer Networks Course Project - Phase 1 Task A
# ==============================================================================

echo "=================================================="
echo " Mac 2 - LAN Network Configuration Discovery"
echo "=================================================="

# Detect active default route interface
ACTIVE_IFACE=$(route -n get default 2>/dev/null | grep 'interface:' | awk '{print $2}')

if [ -z "$ACTIVE_IFACE" ]; then
    ACTIVE_IFACE="en0" # Default fallback for macOS Wi-Fi
fi

echo "Active Interface Name  : $ACTIVE_IFACE"

# Get Private IPv4 Address
IP_ADDR=$(ifconfig "$ACTIVE_IFACE" 2>/dev/null | grep 'inet ' | awk '{print $2}')
echo "Private IPv4 Address   : ${IP_ADDR:-Not Connected}"

# Get Subnet Mask
NETMASK=$(ifconfig "$ACTIVE_IFACE" 2>/dev/null | grep 'inet ' | awk '{print $4}')
echo "Subnet Mask            : ${NETMASK:-Unknown}"

# Get MAC Address
MAC_ADDR=$(ifconfig "$ACTIVE_IFACE" 2>/dev/null | grep 'ether' | awk '{print $2}')
echo "MAC Address            : ${MAC_ADDR:-Unknown}"

# Get Default Gateway / Router IP
GATEWAY=$(netstat -rn -f inet | grep 'default' | awk '{print $2}' | head -n 1)
echo "Default Gateway Router : ${GATEWAY:-Unknown}"

echo "=================================================="
echo " Machine Inventory Table Record (For Architecture Doc):"
echo "| Machine | Role                     | Interface | Private IP      | MAC Address        |"
echo "|---------|--------------------------|-----------|-----------------|--------------------|"
echo "| Mac 2   | Edge Proxy / Load Balancer| $ACTIVE_IFACE      | ${IP_ADDR:-127.0.0.1}     | ${MAC_ADDR:-N/A} |"
echo "=================================================="
