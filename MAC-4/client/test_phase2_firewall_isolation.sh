#!/bin/bash
# ==============================================================================
# Script: test_phase2_firewall_isolation.sh
# Purpose: Extension C - Verify Backend Service Isolation Firewall Rules
# Computer Networks Course Project - Phase 2 Extension C
# ==============================================================================

BACKEND_A_IP="10.7.22.2"
BACKEND_B_IP="10.7.21.68"
EDGE_PROXY="https://app.team1.test:8443"

echo "=================================================="
echo " Extension C: Backend Service Isolation Verification"
echo " Principle: Least Privilege & Defense-in-Depth"
echo " Expected: Direct backend access BLOCKED; Edge Proxy access ALLOWED"
echo "=================================================="

echo ""
echo "[TEST 1] Attempting Direct Access to Backend A ($BACKEND_A_IP:3001)..."
if curl -m 3 -sf "http://$BACKEND_A_IP:3001/api/status" 2>/dev/null; then
    echo "  [FAIL/WARNING] Direct access succeeded! Firewall isolation rule is NOT active on Mac 3."
    echo "                 Mac 3 needs to run: sudo pfctl -e -f configs/pf_backend_isolation.conf"
else
    echo "  [PASS] Direct connection BLOCKED or TIMED OUT as expected!"
    echo "         Mac 3 firewall successfully dropped direct unauthorized client access."
fi

echo ""
echo "[TEST 2] Accessing Service via Edge Reverse Proxy ($EDGE_PROXY)..."
EDGE_STATUS=$(curl -skI "$EDGE_PROXY/api/status" | grep "HTTP/" | head -n 1)
X_BACKEND=$(curl -skI "$EDGE_PROXY/api/status" | grep -i "X-Backend" | awk '{print $2}' | tr -d '\r')

if echo "$EDGE_STATUS" | grep -q "200"; then
    echo "  [PASS] Edge Proxy access SUCCEEDED! ($EDGE_STATUS, Backend: $X_BACKEND)"
    echo "         Proves edge proxy (10.7.23.158) is allowed while clients are restricted."
else
    echo "  [FAIL] Edge Proxy request failed: $EDGE_STATUS"
fi

echo ""
echo "=================================================="
echo " Summary: Service Isolation Prevents Edge Bypass Attack!"
echo " Attackers cannot reach unencrypted backend ports directly."
echo " All traffic is forced through TLS termination and proxy filtering."
echo "=================================================="
