#!/usr/bin/env bash
# ==============================================================================
# Mac 4: Section 8 Final Demonstration Sequence Runner
# Implements exact evaluation steps from faculty guide
# ==============================================================================

EDGE_PORT="${1:-8443}"
DOMAIN="app.team1.test"

echo "=========================================================="
echo "   MAC 4 EVALUATION NODE - SECTION 8 FINAL DEMONSTRATION"
echo "=========================================================="
echo "Target Domain: https://${DOMAIN}:${EDGE_PORT}"
echo ""

echo "--- [Step 3: Domain Resolution] ---"
echo "Command: dig $DOMAIN"
dig "$DOMAIN" +noall +answer +stats
echo ""

echo "--- [Step 4: HTTPS Service Access (Zero Warnings)] ---"
echo "Command: curl https://${DOMAIN}:${EDGE_PORT}/api/status"
curl https://${DOMAIN}:${EDGE_PORT}/api/status
echo -e "\n"

echo "--- [Step 5: Load Balancing Distribution Test (10 requests)] ---"
echo "Command: for i in {1..10}; do curl -s -k https://${DOMAIN}:${EDGE_PORT}/api/status | grep \"backend\"; done"
for i in {1..10}; do
  echo -n "Request #$i: "
  curl -s -k "https://${DOMAIN}:${EDGE_PORT}/api/status" | grep "backend"
  sleep 0.2
done
echo ""

echo "--- [Step 7: HTTP Headers & Caching Demonstration] ---"
echo "[7.1] Initial request to fetch resource & ETag:"
echo "Command: curl -i https://${DOMAIN}:${EDGE_PORT}/cached"
RESP=$(curl -s -i "https://${DOMAIN}:${EDGE_PORT}/cached")
echo "$RESP" | head -n 15

ETAG=$(echo "$RESP" | grep -i "etag:" | awk '{print $2}' | tr -d '\r')
echo -e "\n[*] Captured ETag: $ETAG"

echo ""
echo "[7.2] Conditional request with If-None-Match (Expecting HTTP 304):"
echo "Command: curl -i -H \"If-None-Match: $ETAG\" https://${DOMAIN}:${EDGE_PORT}/cached"
curl -s -i -H "If-None-Match: $ETAG" "https://${DOMAIN}:${EDGE_PORT}/cached" | head -n 12

echo ""
echo "=========================================================="
echo " Demonstration sequence completed!"
echo "=========================================================="
