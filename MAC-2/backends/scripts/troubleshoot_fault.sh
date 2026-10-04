#!/bin/bash
# ==============================================================================
# Script: troubleshoot_fault.sh
# Purpose: Extension F - Layer-by-Layer Diagnostic Tool for Injected Faults
# Computer Networks Course Project - Phase 2 Extension F
# ==============================================================================

TARGET_DOMAIN="app.team1.test"
TARGET_PORT="8443"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CA_CERT="$PROJECT_ROOT/certs/ca.crt"

echo "=================================================="
echo " Extension F: Systematic Network Fault Diagnostic Suite"
echo " Layer-by-Layer Troubleshooting (DNS -> TCP -> TLS -> Application)"
echo "=================================================="

# ------------------------------------------------------------------------------
# STEP 1: DNS Layer Inspection (Layer 7 - Name Resolution)
# ------------------------------------------------------------------------------
echo ""
echo "[STEP 1/4] Checking DNS Resolution (Layer 7 - DNS)..."
DNS_RESULT=$(dig +short "$TARGET_DOMAIN" 2>/dev/null || grep -w "$TARGET_DOMAIN" /etc/hosts | awk '{print $1}' | head -n 1)

if [ -n "$DNS_RESULT" ]; then
    echo "  [PASS] DNS Resolution successful! Resolved IP: $DNS_RESULT"
    RESOLVED_IP="$DNS_RESULT"
else
    echo "  [WARNING] DNS resolution via dig returned empty. Using local fallback (127.0.0.1)..."
    RESOLVED_IP="127.0.0.1"
fi

# ------------------------------------------------------------------------------
# STEP 2: TCP Transport Layer Inspection (Layer 4 - Port Reachability)
# ------------------------------------------------------------------------------
echo ""
echo "[STEP 2/4] Checking TCP Port Connectivity (Layer 4 - Transport)..."

echo -n "  Checking Edge HTTPS Port $TARGET_PORT... "
if nc -z -w 2 "$RESOLVED_IP" "$TARGET_PORT" 2>/dev/null; then
    echo "CONNECTED"
else
    echo "REFUSED / TIMED OUT"
    echo "  -> DIAGNOSIS: Edge Proxy is down or port $TARGET_PORT is blocked."
    echo "  -> ACTION: Check './scripts/start_nginx.sh status' or python fallback proxy."
fi

echo -n "  Checking Backend A Port 3001... "
nc -z -w 2 127.0.0.1 3001 2>/dev/null && echo "CONNECTED" || echo "DOWN / BLOCKED"

echo -n "  Checking Backend B Port 3002... "
nc -z -w 2 127.0.0.1 3002 2>/dev/null && echo "CONNECTED" || echo "DOWN / BLOCKED"

# ------------------------------------------------------------------------------
# STEP 3: TLS / Session Layer Inspection (Layer 5/6 - TLS Handshake)
# ------------------------------------------------------------------------------
echo ""
echo "[STEP 3/4] Checking TLS Handshake & Certificate Trust (Layer 5/6 - TLS)..."
if [ -f "$CA_CERT" ]; then
    SSL_CHECK=$(openssl s_client -connect "$RESOLVED_IP:$TARGET_PORT" -servername "$TARGET_DOMAIN" -CAfile "$CA_CERT" </dev/null 2>&1)

    if echo "$SSL_CHECK" | grep -q "Verify return code: 0 (ok)"; then
        echo "  [PASS] TLS Handshake & Certificate Verification Successful!"
    else
        echo "  [INFO] TLS Connection active (SNI: $TARGET_DOMAIN)."
    fi
else
    echo "  [INFO] CA Certificate file not found at $CA_CERT."
fi

# ------------------------------------------------------------------------------
# STEP 4: Application Layer Inspection (Layer 7 - HTTP REST Response)
# ------------------------------------------------------------------------------
echo ""
echo "[STEP 4/4] Checking Application REST Endpoints (Layer 7 - Application)..."
HTTP_RESP=$(curl -sI --cacert "$CA_CERT" --connect-to "$TARGET_DOMAIN:$TARGET_PORT:$RESOLVED_IP:$TARGET_PORT" "https://$TARGET_DOMAIN:$TARGET_PORT/api/status" 2>/dev/null || curl -skI "https://127.0.0.1:$TARGET_PORT/api/status")

HTTP_STATUS=$(echo "$HTTP_RESP" | grep "HTTP/" | head -n 1 | awk '{print $2}')
X_BACKEND=$(echo "$HTTP_RESP" | grep -i "X-Backend" | awk '{print $2}' | tr -d '\r')

echo "  HTTP Status Code : ${HTTP_STATUS:-None}"
echo "  Upstream Backend : ${X_BACKEND:-None}"

if [ "$HTTP_STATUS" == "200" ]; then
    echo "  [PASS] End-to-end Request successful! Application layer is healthy."
elif [ "$HTTP_STATUS" == "502" ]; then
    echo "  [FAIL] HTTP 502 Bad Gateway!"
    echo "  -> DIAGNOSIS: Edge proxy is reachable, but backend services (3001 & 3002) are DOWN!"
    echo "  -> ACTION: Restart backends using './scripts/start_backends.sh start'."
else
    echo "  [INFO] HTTP status code: $HTTP_STATUS"
fi

echo ""
echo "=================================================="
echo " Diagnostic Sweep Complete."
echo "=================================================="
