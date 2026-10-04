#!/bin/bash
# =============================================================================
# 02_dns_install.sh — Task B: Configure Private DNS Server (dnsmasq)
# Mac 1 | Computer Networks Course Project — Phase 1
# =============================================================================
# FIX: Do NOT use "sudo brew services" — Homebrew cannot run as root on
#      Apple Silicon / modern macOS. We run dnsmasq directly with sudo.
# =============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
DNSMASQ_CONF="${PROJECT_ROOT}/configs/dnsmasq.conf"

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Task B — Private DNS Server Setup  |  Mac 1              ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# ── Pre-flight: check placeholder is replaced (ignore comment lines) ──────────
if grep -v "^\s*#" "${DNSMASQ_CONF}" | grep -q "MAC2_IP"; then
    echo -e "${RED}ERROR: dns/dnsmasq.conf still contains 'MAC2_IP' placeholder.${NC}"
    echo -e "       Open ${DNSMASQ_CONF} and replace MAC2_IP with Mac 2's actual IP."
    exit 1
fi
echo -e "${GREEN}✓ dnsmasq.conf is configured (placeholder removed).${NC}"
echo ""

# =============================================================================
# STEP 1: Install Homebrew if missing
# =============================================================================
echo -e "${YELLOW}[1/5] Checking Homebrew...${NC}"
if ! command -v brew &>/dev/null; then
    echo "  Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo -e "  ${GREEN}✓ Homebrew already installed.${NC}"
fi
echo ""

# =============================================================================
# STEP 2: Install dnsmasq (NO sudo — brew must not run as root)
# =============================================================================
echo -e "${YELLOW}[2/5] Installing dnsmasq...${NC}"
if brew list dnsmasq &>/dev/null 2>&1; then
    echo -e "  ${GREEN}✓ dnsmasq already installed.${NC}"
else
    brew install dnsmasq
fi
DNSMASQ_BIN="$(brew --prefix)/sbin/dnsmasq"
echo -e "  Binary: ${DNSMASQ_BIN}"
echo ""

# =============================================================================
# STEP 3: Deploy configuration to brew's etc directory
# =============================================================================
echo -e "${YELLOW}[3/5] Deploying dnsmasq.conf...${NC}"
DNSMASQ_ETC="$(brew --prefix)/etc/dnsmasq.conf"

if [ -f "${DNSMASQ_ETC}" ]; then
    cp "${DNSMASQ_ETC}" "${DNSMASQ_ETC}.backup.$(date +%Y%m%d%H%M%S)"
    echo "  Backed up existing config."
fi

cp "${DNSMASQ_CONF}" "${DNSMASQ_ETC}"
echo -e "  ${GREEN}✓ Config deployed to: ${DNSMASQ_ETC}${NC}"
echo ""

# =============================================================================
# STEP 4: Kill any old instance, then start dnsmasq directly with sudo
#         (Apple Silicon macOS: "sudo brew services" fails — brew can't be root)
# =============================================================================
echo -e "${YELLOW}[4/5] Starting dnsmasq on port 53 (requires sudo)...${NC}"

sudo pkill -f dnsmasq 2>/dev/null && echo "  Stopped existing dnsmasq." || echo "  No existing dnsmasq to stop."
sleep 1

# Ensure log path exists and is writable
sudo mkdir -p /usr/local/var/log
sudo touch /usr/local/var/log/dnsmasq.log
sudo chmod 666 /usr/local/var/log/dnsmasq.log

# Start dnsmasq in background using our project config file
sudo "${DNSMASQ_BIN}" --conf-file="${DNSMASQ_ETC}"
sleep 2
echo -e "  ${GREEN}✓ dnsmasq launched.${NC}"
echo ""

# =============================================================================
# STEP 5: Confirm port 53 is listening
# =============================================================================
echo -e "${YELLOW}[5/5] Verifying port 53 is open...${NC}"

if sudo lsof -i UDP:53 2>/dev/null | grep -qi dnsmasq || \
   sudo lsof -i TCP:53 2>/dev/null | grep -qi dnsmasq; then
    echo -e "  ${GREEN}✓ dnsmasq is listening on port 53.${NC}"
else
    echo -e "  ${RED}✗ dnsmasq not found on port 53. Showing lsof output:${NC}"
    sudo lsof -i :53 2>/dev/null || echo "  Nothing on port 53"
    echo ""
    echo -e "  Check logs: tail /usr/local/var/log/dnsmasq.log"
    exit 1
fi

echo ""
echo -e "${CYAN}------------------------------------------------------------${NC}"
echo -e "${GREEN}Task B DONE — DNS Server is UP on port 53.${NC}"
echo ""
echo -e "  Run next:   ${CYAN}bash setup/03_dns_test.sh${NC}"
echo ""
echo -e "  Tell teammates to add this IP as their DNS server:"
MY_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "<your LAN IP>")
echo -e "  ${CYAN}networksetup -setdnsservers Wi-Fi ${MY_IP}${NC}"
echo ""
echo -e "  ${YELLOW}Useful commands:${NC}"
echo -e "  Stop dnsmasq   : ${CYAN}sudo pkill -f dnsmasq${NC}"
echo -e "  Check running  : ${CYAN}sudo lsof -i :53${NC}"
echo -e "  View log       : ${CYAN}tail -f /usr/local/var/log/dnsmasq.log${NC}"
echo ""
