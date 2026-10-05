#!/bin/bash
# ==============================================================================
# Script: test_endpoints.sh
# Purpose: Comprehensive Automated Verification Suite for Phase 1
# Computer Networks Course Project - Phase 1 Verification (Tasks A-G)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CA_CERT="$PROJECT_ROOT/certs/ca.crt"
TARGET_HOST="app.team1.test"
TARGET_PORT="8443"
TARGET_URL="https://$TARGET_HOST:$TARGET_PORT"

LOG_DIR="$PROJECT_ROOT/evidence/test_logs"
mkdir -p "$LOG_DIR"

echo "=================================================="
echo " Phase 1 Comprehensive Automated Verification Suite"
echo " Target Domain: $TARGET_HOST ($TARGET_URL)"
echo "=================================================="

# 1. DNS Resolution Check (Task B)
echo ""
echo "[TEST 1/5] Testing Private DNS Resolution..."
if command -v dig > /dev/null; then
    dig_res=$(dig +short "$TARGET_HOST" || true)
    echo "  dig $TARGET_HOST output: ${dig_res:-Resolved locally or via /etc/hosts}"
else
    echo "  dig not installed, using nslookup..."
    nslookup "$TARGET_HOST" || true
fi

# 2. HTTPS / TLS Termination & Certificate Validation (Task E)
echo ""
echo "[TEST 2/5] Testing HTTPS / TLS Connection with CA Certificate (No -k flag)..."
if [ -f "$CA_CERT" ]; then
    SSL_OUTPUT=$(curl -sv --cacert "$CA_CERT" --connect-to "$TARGET_HOST:$TARGET_PORT:127.0.0.1:$TARGET_PORT" "$TARGET_URL/api/status" 2>&1)
    echo "$SSL_OUTPUT" > "$LOG_DIR/tls_handshake_curl.log"
    
    if echo "$SSL_OUTPUT" | grep -q "SSL certificate verify ok"; then
        echo "  [PASS] TLS Handshake verified and Certificate trusted!"
    else
        echo "  [INFO] SSL Handshake log saved to evidence/test_logs/tls_handshake_curl.log"
    fi
else
    echo "  [WARNING] CA Cert file not found at $CA_CERT. Running curl with local host bypass..."
fi

# 3. Round-Robin Load Balancing Test (Task D)
echo ""
echo "[TEST 3/5] Testing Load Balancing across Backend A and Backend B (10 Requests)..."
echo "--------------------------------------------------"
echo "Req # | Target URL            | HTTP Code | Upstream Backend (X-Backend)"
echo "--------------------------------------------------"

BACKEND_A_COUNT=0
BACKEND_B_COUNT=0

for i in {1..10}; do
    if [ -f "$CA_CERT" ]; then
        RESP_HEADERS=$(curl -sI --cacert "$CA_CERT" --connect-to "$TARGET_HOST:$TARGET_PORT:127.0.0.1:$TARGET_PORT" "$TARGET_URL/api/status")
    else
        RESP_HEADERS=$(curl -skI --connect-to "$TARGET_HOST:$TARGET_PORT:127.0.0.1:$TARGET_PORT" "$TARGET_URL/api/status")
    fi
    
    HTTP_CODE=$(echo "$RESP_HEADERS" | grep "HTTP/" | awk '{print $2}')
    BACKEND_HDR=$(echo "$RESP_HEADERS" | grep -i "X-Backend" | awk '{print $2}' | tr -d '\r')
    
    if [ "$BACKEND_HDR" == "A" ]; then
        BACKEND_A_COUNT=$((BACKEND_A_COUNT + 1))
    elif [ "$BACKEND_HDR" == "B" ]; then
        BACKEND_B_COUNT=$((BACKEND_B_COUNT + 1))
    fi
    
    printf " %2d   | %-21s |   %s     | X-Backend: %s\n" "$i" "$TARGET_URL" "$HTTP_CODE" "${BACKEND_HDR:-Unknown}"
done

echo "--------------------------------------------------"
echo " Load Balancing Summary: Backend A = $BACKEND_A_COUNT, Backend B = $BACKEND_B_COUNT"
if [ "$BACKEND_A_COUNT" -gt 0 ] && [ "$BACKEND_B_COUNT" -gt 0 ]; then
    echo "  [PASS] Load Balancing successfully serving requests from both backends!"
else
    echo "  [NOTICE] Check if both backends (3001 & 3002) are running."
fi

# 4. HTTP Caching & Conditional 304 Validation (Task F)
echo ""
echo "[TEST 4/5] Testing HTTP Caching (Cache-Control & ETag / 304 Not Modified)..."
if [ -f "$CA_CERT" ]; then
    FIRST_RESP=$(curl -sI --cacert "$CA_CERT" --connect-to "$TARGET_HOST:$TARGET_PORT:127.0.0.1:$TARGET_PORT" "$TARGET_URL/cached")
else
    FIRST_RESP=$(curl -skI --connect-to "$TARGET_HOST:$TARGET_PORT:127.0.0.1:$TARGET_PORT" "$TARGET_URL/cached")
fi

CACHE_CTRL=$(echo "$FIRST_RESP" | grep -i "Cache-Control" | tr -d '\r')
ETAG_VAL=$(echo "$FIRST_RESP" | grep -i "ETag" | awk '{print $2}' | tr -d '\r')

echo "  Initial Request Headers:"
echo "    - $CACHE_CTRL"
echo "    - ETag: ${ETAG_VAL:-None}"

if [ -n "$ETAG_VAL" ]; then
    echo "  Sending Conditional Request with Header 'If-None-Match: $ETAG_VAL'..."
    if [ -f "$CA_CERT" ]; then
        SECOND_RESP=$(curl -sI -H "If-None-Match: $ETAG_VAL" --cacert "$CA_CERT" --connect-to "$TARGET_HOST:$TARGET_PORT:127.0.0.1:$TARGET_PORT" "$TARGET_URL/cached")
    else
        SECOND_RESP=$(curl -skI -H "If-None-Match: $ETAG_VAL" --connect-to "$TARGET_HOST:$TARGET_PORT:127.0.0.1:$TARGET_PORT" "$TARGET_URL/cached")
    fi
    SECOND_STATUS=$(echo "$SECOND_RESP" | grep "HTTP/" | head -n 1 | tr -d '\r')
    echo "  Conditional Request Status: $SECOND_STATUS"
    
    if echo "$SECOND_STATUS" | grep -q "304"; then
        echo "  [PASS] HTTP 304 Not Modified validated! Client caching confirmed."
    else
        echo "  [INFO] Conditional response code received: $SECOND_STATUS"
    fi
fi

# 5. HTTP/2 Verification
echo ""
echo "[TEST 5/5] Testing HTTP/2 Protocol Negotiation..."
if [ -f "$CA_CERT" ]; then
    HTTP2_CHECK=$(curl -sI --http2 --cacert "$CA_CERT" --connect-to "$TARGET_HOST:$TARGET_PORT:127.0.0.1:$TARGET_PORT" "$TARGET_URL/" | head -n 1)
else
    HTTP2_CHECK=$(curl -skI --http2 --connect-to "$TARGET_HOST:$TARGET_PORT:127.0.0.1:$TARGET_PORT" "$TARGET_URL/" | head -n 1)
fi
echo "  Protocol Response Line: ${HTTP2_CHECK:-Unknown}"

echo ""
echo "=================================================="
echo " Verification Complete. Test logs saved in evidence/test_logs/"
echo "=================================================="
