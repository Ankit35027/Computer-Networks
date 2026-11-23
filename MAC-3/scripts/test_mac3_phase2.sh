#!/bin/bash
# ==============================================================================
# Script: test_mac3_phase2.sh
# Purpose: Local Phase 2 Verification Suite for Mac 3
# Validates: Backend A, Backup DNS Resolver, PF Firewall Isolation, Standby Edge
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAC3_DIR="$(dirname "$SCRIPT_DIR")"

echo "=================================================="
echo " Mac 3 - Phase 2 Verification Suite"
echo " Services: Backend A (:3001), Backup DNS (:53), Standby Edge (:8443)"
echo "=================================================="

echo ""
echo "[TEST 1/4] Testing Backend A (/api/status on port 3001)..."
BACKEND_RESP=$(curl -s http://127.0.0.1:3001/api/status 2>/dev/null || echo "")
if echo "$BACKEND_RESP" | grep -q '"backend":"A"'; then
    echo "  [PASS] Backend A is UP! Response: $BACKEND_RESP"
else
    echo "  [FAIL] Backend A is DOWN or not responding on port 3001."
fi

echo ""
echo "[TEST 2/4] Testing Backup DNS Resolver (dnsmasq on port 53)..."
DNS_RESP=$(dig @127.0.0.1 -p 53 +short app.team1.test 2>/dev/null || echo "")
if [ -n "$DNS_RESP" ]; then
    echo "  [PASS] Backup DNS Resolver is active! Resolved app.team1.test -> $DNS_RESP"
else
    echo "  [WARNING] Backup DNS Resolver not responding on 127.0.0.1:53."
    echo "            Start it using: sudo dnsmasq -C configs/dnsmasq_backup.conf"
fi

echo ""
echo "[TEST 3/4] Testing PF Service Isolation Rules..."
PF_STATUS=$(sudo pfctl -s rules 2>/dev/null | grep -E "3001" || echo "")
if [ -n "$PF_STATUS" ]; then
    echo "  [PASS] Active isolation rules found for port 3001:"
    echo "$PF_STATUS" | sed 's/^/    /'
else
    echo "  [INFO] PF firewall rules not active. Enable with: sudo ./scripts/pf_isolation.sh enable 3001  (repo root)"
fi

echo ""
echo "[TEST 4/4] Testing Standby Edge Proxy (/api/status on port 8443)..."
STANDBY_RESP=$(curl -skI https://127.0.0.1:8443/api/status 2>/dev/null || echo "")
if echo "$STANDBY_RESP" | grep -q "200 OK"; then
    echo "  [PASS] Standby Edge Proxy is active on port 8443!"
else
    echo "  [INFO] Standby Edge Proxy not running on port 8443 (start via start-all.sh if testing cutover)."
fi

echo ""
echo "=================================================="
echo " Mac 3 Verification Complete."
echo "=================================================="
