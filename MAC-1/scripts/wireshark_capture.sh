#!/bin/bash
# =============================================================================
# wireshark_capture.sh — Task G: Capture DNS + TCP + TLS packets
# Mac 1 | Run this AFTER dnsmasq is started
# =============================================================================
# This captures into a .pcapng file you open in Wireshark GUI.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVIDENCE_DIR="${SCRIPT_DIR}/../evidence/captures"
mkdir -p "${EVIDENCE_DIR}"
CAPTURE_FILE="${EVIDENCE_DIR}/wireshark_capture_$(date +%Y%m%d_%H%M%S).pcapng"
MAC1_IP="$(ipconfig getifaddr en0 2>/dev/null || echo '127.0.0.1')"
MAC2_IP="10.7.23.158"
DOMAIN="app.team1.test"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Task G — Packet Capture  |  Mac 1                       ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "  Mac 1 LAN IP: ${MAC1_IP}"
echo -e "  Mac 2 Edge IP: ${MAC2_IP}"
echo -e "  Capture file : ${CAPTURE_FILE}"
echo ""

# ── Start tcpdump in background ───────────────────────────────────────────────
echo -e "${YELLOW}[1/4] Starting packet capture on en0...${NC}"
sudo tcpdump -i en0 \
  "(udp port 53) or (host ${MAC2_IP} and tcp port 8443)" \
  -w "${CAPTURE_FILE}" 2>/dev/null &
TCPDUMP_PID=$!
sleep 2
echo -e "  ${GREEN}✓ Capture running (PID ${TCPDUMP_PID})${NC}"
echo ""

# ── Trigger DNS query ─────────────────────────────────────────────────────────
echo -e "${YELLOW}[2/4] Triggering DNS query (captures UDP/53 on en0)...${NC}"
dig @"${MAC1_IP}" "${DOMAIN}"
echo -e "  ${GREEN}✓ DNS query sent to ${MAC1_IP}${NC}"
echo ""
sleep 1

# ── Trigger TCP + TLS + HTTP ──────────────────────────────────────────────────
echo -e "${YELLOW}[3/4] Triggering HTTPS requests (captures TCP handshake + TLS)...${NC}"
for i in {1..4}; do
    curl -sk --connect-timeout 2 --resolve "${DOMAIN}:8443:${MAC2_IP}" \
        "https://${DOMAIN}:8443/api/status" > /dev/null || true
    sleep 0.5
done
echo -e "  ${GREEN}✓ HTTPS requests sent${NC}"
echo ""
sleep 2

# ── Stop capture ──────────────────────────────────────────────────────────────
echo -e "${YELLOW}[4/4] Stopping capture cleanly...${NC}"
sudo kill -2 "${TCPDUMP_PID}" 2>/dev/null
wait "${TCPDUMP_PID}" 2>/dev/null
sleep 1
echo -e "  ${GREEN}✓ Capture saved to:${NC}"
echo -e "    ${CYAN}${CAPTURE_FILE}${NC}"
echo ""

# ── Print file size ───────────────────────────────────────────────────────────
SIZE=$(du -h "${CAPTURE_FILE}" 2>/dev/null | cut -f1)
echo -e "  File size: ${SIZE}"
echo ""

echo -e "${CYAN}============================================================${NC}"
echo -e "${GREEN}NOW: Open Wireshark and load this file:${NC}"
echo -e "  ${CYAN}open -a Wireshark '${CAPTURE_FILE}'${NC}"
echo ""
echo -e "${YELLOW}Wireshark filters to use for evidence screenshots:${NC}"
echo ""
echo -e "  DNS packets      : ${CYAN}dns${NC}"
echo -e "  TCP handshake    : ${CYAN}tcp.flags.syn == 1${NC}"
echo -e "  TLS handshake    : ${CYAN}tls.handshake${NC}"
echo -e "  All TLS traffic  : ${CYAN}tls${NC}"
echo -e "  Everything       : ${CYAN}ip.addr == ${MAC2_IP}${NC}"
echo ""
echo -e "${YELLOW}Screenshots you MUST take for Task G:${NC}"
echo -e "  1. DNS  : Filter 'dns'          → screenshot the Query + Response rows"
echo -e "  2. TCP  : Filter 'tcp.flags.syn == 1' → screenshot SYN, SYN-ACK, ACK"
echo -e "  3. TLS  : Filter 'tls.handshake' → screenshot ClientHello, ServerHello, Certificate"
echo -e "  4. Click any TLS row → expand packet details panel → show it is encrypted"
echo -e "${CYAN}============================================================${NC}"
echo ""

# Auto-open in Wireshark
open -a Wireshark "${CAPTURE_FILE}" 2>/dev/null && \
    echo -e "${GREEN}Wireshark opened with the capture file!${NC}" || \
    echo -e "  Open manually: File → Open → ${CAPTURE_FILE}"
echo ""
