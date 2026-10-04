#!/bin/bash
# =============================================================================
# 01_lan_verify.sh — Task A: Establish the Private LAN
# Mac 1 | Computer Networks Course Project — Phase 1
# =============================================================================
# Run this script FIRST after connecting to the shared Wi-Fi/LAN.
# It records your machine info and lets you ping all other team Macs.
# Save this output — you need it for the Architecture Document.
# =============================================================================

set -e

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Task A — LAN Verification  |  Mac 1 (DNS Server)         ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# =============================================================================
# SECTION 1: Your Machine's Network Info
# =============================================================================
echo -e "${YELLOW}[1/3] Collecting Mac 1 Network Information...${NC}"
echo ""

# Detect the active network interface (usually en0 for Wi-Fi)
ACTIVE_IF=$(route get default 2>/dev/null | grep interface | awk '{print $2}')
echo -e "  Active Interface : ${GREEN}${ACTIVE_IF}${NC}"

# Private IPv4 address on that interface
MY_IP=$(ipconfig getifaddr "${ACTIVE_IF}" 2>/dev/null || echo "NOT FOUND")
echo -e "  Private IPv4     : ${GREEN}${MY_IP}${NC}"

# Subnet mask
SUBNET=$(ipconfig getoption "${ACTIVE_IF}" subnet_mask 2>/dev/null || echo "NOT FOUND")
echo -e "  Subnet Mask      : ${GREEN}${SUBNET}${NC}"

# Default gateway
GATEWAY=$(route get default 2>/dev/null | grep gateway | awk '{print $2}')
echo -e "  Default Gateway  : ${GREEN}${GATEWAY}${NC}"

# MAC address
MAC_ADDR=$(ifconfig "${ACTIVE_IF}" 2>/dev/null | grep ether | awk '{print $2}')
echo -e "  MAC Address      : ${GREEN}${MAC_ADDR}${NC}"

echo ""
echo -e "  ${YELLOW}► Save these values in your Architecture Document.${NC}"
echo ""

# =============================================================================
# SECTION 2: Ping Other Team Macs
# =============================================================================
echo -e "${YELLOW}[2/3] Pinging Team Machines...${NC}"
echo ""
echo -e "  ${CYAN}Edit the IPs below before running! Replace with your team's actual IPs.${NC}"
echo ""

MAC2_IP="10.7.23.158"   # Edge / Reverse Proxy (nginx)
MAC3_IP="10.7.22.2"     # Backend A (port 3001)
MAC4_IP="10.7.21.68"    # Backend B (port 3002) + Test Client

ping_check() {
    local label=$1
    local ip=$2
    if [[ "$ip" == *"X"* ]]; then
        echo -e "  ${YELLOW}⚠ ${label} (${ip}) — IP not set yet. Edit this script.${NC}"
        return
    fi
    printf "  Pinging %-30s ... " "${label} (${ip})"
    if ping -c 3 -W 1000 "${ip}" &>/dev/null; then
        echo -e "${GREEN}✓ Reachable${NC}"
    else
        echo -e "${RED}✗ UNREACHABLE${NC}"
    fi
}

ping_check "Mac 2 (nginx Edge)"    "${MAC2_IP}"
ping_check "Mac 3 (Backend A)"     "${MAC3_IP}"
ping_check "Mac 4 (Backend B)"     "${MAC4_IP}"

echo ""

# =============================================================================
# SECTION 3: Summary Table (copy into your Architecture Document)
# =============================================================================
echo -e "${YELLOW}[3/3] IP & Role Summary Table${NC}"
echo ""
echo "  ┌──────┬──────────────────────────────┬─────────────────┬───────────┐"
echo "  │ Mac  │ Role                         │ IP Address      │ Interface │"
echo "  ├──────┼──────────────────────────────┼─────────────────┼───────────┤"
printf "  │ Mac1 │ %-28s │ %-15s │ %-9s │\n" "DNS Server + Test Client" "${MY_IP}" "${ACTIVE_IF}"
printf "  │ Mac2 │ %-28s │ %-15s │ %-9s │\n" "nginx Edge + Load Balancer" "${MAC2_IP}" "en0"
printf "  │ Mac3 │ %-28s │ %-15s │ %-9s │\n" "Backend A (port 3001)" "${MAC3_IP}" "en0"
printf "  │ Mac4 │ %-28s │ %-15s │ %-9s │\n" "Backend B (port 3002)" "${MAC4_IP}" "en0"
echo "  └──────┴──────────────────────────────┴─────────────────┴───────────┘"
echo ""
echo -e "${GREEN}Task A complete. Save the table above in your Architecture Document.${NC}"
echo ""
