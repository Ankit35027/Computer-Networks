#!/bin/bash
# =============================================================================
# 03_dns_test.sh — Task B/G: Verify DNS Resolution + Test Client Commands
# Mac 1 | Computer Networks Course Project — Phase 1
# =============================================================================
# Run this after 02_dns_install.sh.
# This script:
#   1. Tests local DNS resolution using dig
#   2. Tests resolution from a client perspective (pointing to self as DNS)
#   3. Shows what to run on other client Macs
#   4. Prints curl test commands once Mac 2 is up
# =============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

MY_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "UNKNOWN")
DOMAIN_APP="app.team1.test"
DOMAIN_API="api.team1.test"

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Task B/G — DNS Resolution Tests  |  Mac 1 (DNS Server)   ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# =============================================================================
# CHECK: Is dnsmasq running?
# =============================================================================
if ! sudo lsof -i UDP:53 2>/dev/null | grep -qi dnsmasq && \
   ! sudo lsof -i TCP:53 2>/dev/null | grep -qi dnsmasq; then
    echo -e "${RED}WARNING: dnsmasq is not listening on port 53.${NC}"
    echo -e "  Run: bash setup/02_dns_install.sh"
    echo ""
fi

# =============================================================================
# TEST 1: dig directly against localhost
# =============================================================================
echo -e "${YELLOW}[TEST 1] Querying dnsmasq directly on localhost (127.0.0.1)...${NC}"
echo -e "  Command: ${CYAN}dig @127.0.0.1 ${DOMAIN_APP}${NC}"
echo ""

RESULT=$(dig @127.0.0.1 "${DOMAIN_APP}" +short 2>/dev/null)
if [ -n "${RESULT}" ]; then
    echo -e "  ${GREEN}✓ ${DOMAIN_APP} resolved to: ${RESULT}${NC}"
else
    echo -e "  ${RED}✗ No answer — check dnsmasq.conf has the correct IP (not MAC2_IP placeholder).${NC}"
fi

echo ""

# =============================================================================
# TEST 2: dig against Mac 1's LAN IP (simulates another machine querying you)
# =============================================================================
echo -e "${YELLOW}[TEST 2] Querying dnsmasq via Mac 1's LAN IP (${MY_IP})...${NC}"
echo -e "  Command: ${CYAN}dig @${MY_IP} ${DOMAIN_APP}${NC}"
echo ""

RESULT2=$(dig @"${MY_IP}" "${DOMAIN_APP}" +short 2>/dev/null)
if [ -n "${RESULT2}" ]; then
    echo -e "  ${GREEN}✓ ${DOMAIN_APP} resolved to: ${RESULT2}${NC}"
    echo -e "  ${GREEN}  Other Macs can use ${MY_IP} as their DNS server.${NC}"
else
    echo -e "  ${RED}✗ No answer via LAN IP. Firewall may be blocking port 53.${NC}"
    echo -e "  Try: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add \$(which dnsmasq)"
fi

echo ""

# =============================================================================
# TEST 3: dig with full verbose output (for evidence screenshots)
# =============================================================================
echo -e "${YELLOW}[TEST 3] Full dig output for ${DOMAIN_APP} (save this for evidence)...${NC}"
echo -e "  Command: ${CYAN}dig @127.0.0.1 ${DOMAIN_APP} ANY${NC}"
echo ""
dig @127.0.0.1 "${DOMAIN_APP}" ANY 2>/dev/null || echo -e "${RED}dig command failed.${NC}"

echo ""

# =============================================================================
# TEST 4: nslookup (alternative evidence method)
# =============================================================================
echo -e "${YELLOW}[TEST 4] nslookup test (alternative to dig)...${NC}"
echo -e "  Command: ${CYAN}nslookup ${DOMAIN_APP} 127.0.0.1${NC}"
echo ""
nslookup "${DOMAIN_APP}" 127.0.0.1 2>/dev/null || echo -e "${RED}nslookup failed.${NC}"

echo ""

# =============================================================================
# TEST 5: api.team1.test resolution
# =============================================================================
echo -e "${YELLOW}[TEST 5] Checking api.team1.test resolution...${NC}"
echo -e "  Command: ${CYAN}dig @127.0.0.1 ${DOMAIN_API} +short${NC}"
echo ""
RESULT3=$(dig @127.0.0.1 "${DOMAIN_API}" +short 2>/dev/null)
if [ -n "${RESULT3}" ]; then
    echo -e "  ${GREEN}✓ ${DOMAIN_API} resolved to: ${RESULT3}${NC}"
else
    echo -e "  ${RED}✗ No answer for ${DOMAIN_API}${NC}"
fi

echo ""
echo -e "${CYAN}------------------------------------------------------------${NC}"
echo -e "${GREEN}DNS Tests Complete.${NC}"
echo ""

# =============================================================================
# INSTRUCTIONS FOR OTHER TEAM MACS
# =============================================================================
echo -e "${YELLOW}► Tell your teammates to set DNS on their Macs:${NC}"
echo ""
echo -e "  System Preferences → Network → [Wi-Fi] → Advanced → DNS tab"
echo -e "  Click [+] and add: ${CYAN}${MY_IP}${NC}"
echo -e "  Move it to the TOP of the DNS list."
echo ""
echo -e "  Or via Terminal on their Mac:"
echo -e "  ${CYAN}networksetup -setdnsservers Wi-Fi ${MY_IP}${NC}"
echo ""

# =============================================================================
# CURL TESTS (once Mac 2 nginx is up)
# =============================================================================
echo -e "${YELLOW}► Once Mac 2 nginx is running, test the full chain from Mac 1:${NC}"
echo ""
echo -e "  # Set Mac 1 to use its own DNS:"
echo -e "  ${CYAN}sudo networksetup -setdnsservers Wi-Fi 127.0.0.1${NC}"
echo ""
echo -e "  # HTTPS request (no -k flag in final demo):"
echo -e "  ${CYAN}curl -v https://app.team1.test/api/status${NC}"
echo ""
echo -e "  # Show response headers (for caching demo):"
echo -e "  ${CYAN}curl -I https://app.team1.test/api/status${NC}"
echo ""
echo -e "  # Watch load balancing across backends (run 6 times):"
echo -e "  ${CYAN}for i in {1..6}; do curl -s https://app.team1.test/api/status | python3 -m json.tool; done${NC}"
echo ""
echo -e "${CYAN}------------------------------------------------------------${NC}"
echo ""
