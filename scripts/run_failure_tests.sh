#!/bin/bash
# ==============================================================================
# Script: run_failure_tests.sh
# Purpose: Simulates and logs Section 6.3 Mandatory Failure Demonstrations
# Computer Networks Course Project - Phase 1 Failure Scenarios
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CA_CERT="$PROJECT_ROOT/certs/ca.crt"
TARGET_HOST="app.team1.test"

echo "=================================================="
echo " Section 6.3 Mandatory Failure Scenarios Simulation"
echo "=================================================="

# Scenario 1: Wrong DNS Server configured on client
echo ""
echo "[SCENARIO 1] Wrong DNS Server configured on client"
echo "  Action: Attempting DNS resolution against invalid DNS IP (192.0.2.1)..."
dig @192.0.2.1 "$TARGET_HOST" +time=2 +tries=1 2>&1 | head -n 8 || true
echo "  Explanation: Name lookup fails due to unreachability of DNS server. Demonstrates that DNS layer is independent from direct IP connectivity."

# Scenario 2: DNS record points to a wrong IP address
echo ""
echo "[SCENARIO 2] DNS record points to a wrong IP address"
echo "  Action: Attempting HTTP connection to incorrect destination IP (192.0.2.50)..."
curl --connect-timeout 2 -sv "http://192.0.2.50:8080/api/status" 2>&1 | head -n 6 || true
echo "  Explanation: DNS lookup succeeds but client attempts connection to wrong IP. Demonstrates DNS is a lookup directory, not a connection."

# Scenario 3: One backend is stopped
echo ""
echo "[SCENARIO 3] One backend (Backend A on port 3001) is stopped"
echo "  Action: Stopping Backend A while leaving Backend B running..."
pkill -f "backend_a.py" 2>/dev/null || true
sleep 1
echo "  Testing Nginx failover to remaining healthy backend (Backend B)..."
for i in {1..3}; do
    curl -skI --connect-to "$TARGET_HOST:8443:127.0.0.1:8443" "https://$TARGET_HOST:8443/api/status" | grep -E "HTTP/|X-Backend" || true
done
echo "  Explanation: Nginx detects port 3001 connection failure and routes requests to Backend B seamlessly."

# Scenario 4: Both backends are stopped
echo ""
echo "[SCENARIO 4] Both backends (Backend A & B) are stopped"
echo "  Action: Stopping Backend B on port 3002..."
pkill -f "backend_b.py" 2>/dev/null || true
sleep 1
echo "  Sending HTTPS request to Nginx edge..."
curl -skI --connect-to "$TARGET_HOST:8443:127.0.0.1:8443" "https://$TARGET_HOST:8443/api/status" | grep -E "HTTP/|502" || true
echo "  Explanation: Returns '502 Bad Gateway'. DNS & TLS succeed at edge Nginx layer, but edge cannot reach upstream backends."

# Scenario 5: Wrong destination port on client
echo ""
echo "[SCENARIO 5] Wrong destination port on client"
echo "  Action: Attempting HTTPS request on closed port 9999..."
curl --connect-timeout 2 -sv "https://127.0.0.1:9999/" 2>&1 | head -n 6 || true
echo "  Explanation: Host is reachable, but TCP connection to port 9999 is refused. Demonstrates IP addresses and TCP port numbers operate at distinct layers."

echo ""
echo "Restarting backend servers to restore normal state..."
"$SCRIPT_DIR/start_backends.sh" start
echo "=================================================="
echo " Failure Demonstrations Simulation Complete."
echo "=================================================="
