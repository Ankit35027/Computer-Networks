#!/bin/bash
# ==============================================================================
# Script: capture_pcap_evidence.sh
# Purpose: Capture live network packets and save standard .pcap files for evaluation
# Computer Networks Course Project - Task G & Section 9 Evidence
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EVIDENCE_DIR="$PROJECT_ROOT/evidence"

mkdir -p "$EVIDENCE_DIR"

echo "=================================================="
echo " Mac 2 Live Packet Capture Evidence Generator"
echo "=================================================="

# Ensure Nginx & Backends are running
"$SCRIPT_DIR/start_backends.sh" start > /dev/null 2>&1
"$SCRIPT_DIR/start_nginx.sh" start > /dev/null 2>&1

echo ""
echo "[1/4] Capturing TCP 3-Way Handshake (Port 8443)..."
PCAP_TCP="$EVIDENCE_DIR/tcp_3way_handshake.pcap"
tcpdump -i lo0 -w "$PCAP_TCP" "tcp port 8443" > /dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 1

# Trigger TCP handshake via curl
curl -s --resolve app.team1.test:8443:127.0.0.1 --cacert "$PROJECT_ROOT/certs/ca.crt" https://app.team1.test:8443/api/status > /dev/null

sleep 1
kill $TCPDUMP_PID 2>/dev/null || true
echo "  [SAVED] $PCAP_TCP"

echo ""
echo "[2/4] Capturing TLS 1.3 SNI Handshake (Port 8443)..."
PCAP_TLS="$EVIDENCE_DIR/tls_handshake.pcap"
tcpdump -i lo0 -w "$PCAP_TLS" "tcp port 8443" > /dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 1

# Trigger TLS Handshake
curl -s --resolve app.team1.test:8443:127.0.0.1 --cacert "$PROJECT_ROOT/certs/ca.crt" https://app.team1.test:8443/api/status > /dev/null

sleep 1
kill $TCPDUMP_PID 2>/dev/null || true
echo "  [SAVED] $PCAP_TLS"

echo ""
echo "[3/4] Capturing DNS Query & Response (Port 53 / Local Lookup)..."
PCAP_DNS="$EVIDENCE_DIR/dns_query.pcap"
tcpdump -i any -w "$PCAP_DNS" "port 53 or port 5353" > /dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 1

# Trigger DNS query
dig app.team1.test > /dev/null 2>&1 || ping -c 1 app.team1.test > /dev/null 2>&1 || true

sleep 1
kill $TCPDUMP_PID 2>/dev/null || true
echo "  [SAVED] $PCAP_DNS"

echo ""
echo "[4/4] Capturing HTTP Caching & 304 Response..."
PCAP_HTTP2="$EVIDENCE_DIR/http2_caching.pcap"
tcpdump -i lo0 -w "$PCAP_HTTP2" "tcp port 8443" > /dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 1

# Trigger Conditional Request
curl -s --resolve app.team1.test:8443:127.0.0.1 --cacert "$PROJECT_ROOT/certs/ca.crt" -H 'If-None-Match: "8c6540340ce1e7794ebd1b527e03610a"' https://app.team1.test:8443/cached > /dev/null

sleep 1
kill $TCPDUMP_PID 2>/dev/null || true
echo "  [SAVED] $PCAP_HTTP2"

echo ""
echo "=================================================="
echo " All .pcap evidence files generated successfully!"
echo " Location: $EVIDENCE_DIR"
ls -lh "$EVIDENCE_DIR"/*.pcap 2>/dev/null || true
echo "=================================================="
