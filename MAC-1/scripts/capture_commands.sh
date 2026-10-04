#!/bin/bash
# =============================================================================
# capture_commands.sh — Task G: Collect Protocol Flow Evidence
# Mac 1 | Computer Networks Course Project — Phase 1
# =============================================================================
# Run these commands to collect Wireshark + dig + curl evidence.
# All evidence must be ready before the Phase 1 review.
#
# PREREQUISITES:
#   - Mac 2 nginx must be UP and serving HTTPS
#   - Mac 1 DNS must be set as resolver on this machine
#   - Wireshark must be installed: brew install --cask wireshark
# =============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

EVIDENCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DOMAIN="app.team1.test"

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Task G — Protocol Flow Evidence Collection  |  Mac 1     ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# =============================================================================
# EVIDENCE 1: DNS Query + Response (dig full output)
# =============================================================================
echo -e "${YELLOW}[EVIDENCE 1] DNS Resolution — dig full output${NC}"
echo -e "  Saved to: ${EVIDENCE_DIR}/dns_query_${TIMESTAMP}.txt"
echo ""

{
    echo "=== DNS EVIDENCE: dig app.team1.test ==="
    echo "Timestamp: $(date)"
    echo ""
    echo "--- Query via Mac 1 DNS (127.0.0.1) ---"
    dig @127.0.0.1 "${DOMAIN}" 2>/dev/null
    echo ""
    echo "--- Short answer ---"
    dig @127.0.0.1 "${DOMAIN}" +short 2>/dev/null
    echo ""
    echo "--- nslookup ---"
    nslookup "${DOMAIN}" 127.0.0.1 2>/dev/null
} | tee "${EVIDENCE_DIR}/dns_query_${TIMESTAMP}.txt"

echo ""

# =============================================================================
# EVIDENCE 2: TCP + TLS + HTTP — curl verbose
# =============================================================================
echo -e "${YELLOW}[EVIDENCE 2] TCP/TLS/HTTP — curl verbose output${NC}"
echo -e "  Saved to: ${EVIDENCE_DIR}/curl_verbose_${TIMESTAMP}.txt"
echo ""

{
    echo "=== CURL VERBOSE EVIDENCE ==="
    echo "Timestamp: $(date)"
    echo ""
    echo "Command: curl -v https://${DOMAIN}/api/status"
    echo ""
    curl -v "https://${DOMAIN}/api/status" 2>&1 || \
    curl -v -k "https://${DOMAIN}/api/status" 2>&1  # fallback if cert not trusted yet
} | tee "${EVIDENCE_DIR}/curl_verbose_${TIMESTAMP}.txt"

echo ""

# =============================================================================
# EVIDENCE 3: HTTP Headers (for cache demo — Task F)
# =============================================================================
echo -e "${YELLOW}[EVIDENCE 3] HTTP Headers — Cache-Control / ETag${NC}"
echo -e "  Saved to: ${EVIDENCE_DIR}/http_headers_${TIMESTAMP}.txt"
echo ""

{
    echo "=== HTTP HEADERS EVIDENCE ==="
    echo "Timestamp: $(date)"
    echo ""
    echo "--- First request (cache miss): ---"
    curl -sI "https://${DOMAIN}/api/status" 2>/dev/null || \
    curl -skI "https://${DOMAIN}/api/status" 2>/dev/null
    echo ""
    echo "--- Second request (may return 304): ---"
    curl -sI "https://${DOMAIN}/api/status" 2>/dev/null || \
    curl -skI "https://${DOMAIN}/api/status" 2>/dev/null
} | tee "${EVIDENCE_DIR}/http_headers_${TIMESTAMP}.txt"

echo ""

# =============================================================================
# EVIDENCE 4: Load Balancing — X-Backend header alternating
# =============================================================================
echo -e "${YELLOW}[EVIDENCE 4] Load Balancing — X-Backend header (6 requests)${NC}"
echo -e "  Saved to: ${EVIDENCE_DIR}/load_balance_${TIMESTAMP}.txt"
echo ""

{
    echo "=== LOAD BALANCING EVIDENCE ==="
    echo "Timestamp: $(date)"
    echo ""
    echo "Sending 6 requests to https://${DOMAIN}/api/status"
    echo "Watch X-Backend header alternate between A and B:"
    echo ""
    for i in {1..6}; do
        echo -n "Request ${i}: "
        curl -s "https://${DOMAIN}/api/status" 2>/dev/null | python3 -m json.tool 2>/dev/null || \
        curl -sk "https://${DOMAIN}/api/status" 2>/dev/null
        echo ""
    done
} | tee "${EVIDENCE_DIR}/load_balance_${TIMESTAMP}.txt"

echo ""

# =============================================================================
# EVIDENCE 5: Port identification
# =============================================================================
echo -e "${YELLOW}[EVIDENCE 5] Port Identification — active connections${NC}"
echo -e "  Saved to: ${EVIDENCE_DIR}/ports_${TIMESTAMP}.txt"
echo ""

{
    echo "=== PORT EVIDENCE ==="
    echo "Timestamp: $(date)"
    echo ""
    echo "--- Active connections after HTTPS request: ---"
    netstat -an | grep -E "ESTABLISHED|53|443|8443" 2>/dev/null
    echo ""
    echo "--- Ephemeral ports in use: ---"
    netstat -an | grep "ESTABLISHED" | head -20 2>/dev/null
} | tee "${EVIDENCE_DIR}/ports_${TIMESTAMP}.txt"

echo ""

# =============================================================================
# EVIDENCE 6: DNS log (what dnsmasq received)
# =============================================================================
echo -e "${YELLOW}[EVIDENCE 6] dnsmasq Query Log (last 50 lines)${NC}"
echo -e "  Saved to: ${EVIDENCE_DIR}/dnsmasq_log_${TIMESTAMP}.txt"
echo ""

DNSMASQ_LOG="$(brew --prefix 2>/dev/null)/var/log/dnsmasq.log"
if [ -f "${DNSMASQ_LOG}" ]; then
    {
        echo "=== DNSMASQ LOG EVIDENCE ==="
        echo "Timestamp: $(date)"
        echo ""
        tail -50 "${DNSMASQ_LOG}"
    } | tee "${EVIDENCE_DIR}/dnsmasq_log_${TIMESTAMP}.txt"
else
    echo -e "  Log not found at ${DNSMASQ_LOG}. Check dnsmasq.conf log-facility setting."
fi

echo ""

# =============================================================================
# WIRESHARK INSTRUCTIONS
# =============================================================================
echo -e "${CYAN}============================================================${NC}"
echo -e "${YELLOW}  Wireshark Capture Instructions (Manual Steps)           ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "  1. Open Wireshark (install: brew install --cask wireshark)"
echo -e "  2. Select interface: ${CYAN}en0${NC} (Wi-Fi)"
echo -e ""
echo -e "  3. Use these capture filters:"
echo -e "     ${CYAN}DNS only      :  udp port 53${NC}"
echo -e "     ${CYAN}HTTPS only    :  tcp port 443 or tcp port 8443${NC}"
echo -e "     ${CYAN}All traffic   :  host <MAC2_IP>${NC}"
echo -e ""
echo -e "  4. While capturing, run:"
echo -e "     ${CYAN}dig @127.0.0.1 app.team1.test${NC}           ← captures DNS"
echo -e "     ${CYAN}curl -v https://app.team1.test/api/status${NC} ← captures TCP+TLS+HTTP"
echo -e ""
echo -e "  5. What to find in Wireshark:"
echo -e "     ${GREEN}DNS  :${NC} Filter: dns  → Look for Query (A) and Response packets"
echo -e "     ${GREEN}TCP  :${NC} Filter: tcp.flags.syn==1  → SYN, SYN-ACK, ACK handshake"
echo -e "     ${GREEN}TLS  :${NC} Filter: tls  → ClientHello, ServerHello, Certificate"
echo -e "     ${GREEN}HTTP :${NC} (encrypted) Filter: tls.app_data  → payload is ciphertext"
echo -e ""
echo -e "  6. Save the capture: File → Save As → wireshark_capture_${TIMESTAMP}.pcapng"
echo -e "     Put it in the ${EVIDENCE_DIR}/ folder."
echo ""
echo -e "${GREEN}Evidence collection complete. Files saved in evidence/ folder.${NC}"
echo ""
