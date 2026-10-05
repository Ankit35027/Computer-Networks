#!/usr/bin/env bash
# ==============================================================================
# Task F: Demonstrate HTTP Caching Behavior (Cache-Control, ETag, 304)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../network/team_ips.env" ]; then
  source "$SCRIPT_DIR/../network/team_ips.env"
fi

DOMAIN="${1:-${TEAM_DOMAIN:-app.team1.test}}"
CACHED_URL="https://${DOMAIN}/api/cached"

echo "=========================================================="
echo "          TASK F: HTTP CACHING DEMONSTRATION"
echo "=========================================================="
echo "Endpoint: $CACHED_URL"
echo ""

echo "--- [Step 1] Initial Request (Fetching Fresh Resource) ---"
echo "Executing: curl -i -s '$CACHED_URL'"
echo ""
RESP1=$(curl -i -s "$CACHED_URL")
echo "$RESP1" | head -n 15

# Extract ETag
ETAG=$(echo "$RESP1" | grep -i "etag:" | awk '{print $2}' | tr -d '\r')
echo ""
echo "[*] Extracted ETag from response: $ETAG"

echo ""
echo "--- [Step 2] Conditional Request with 'If-None-Match' ---"
echo "Executing: curl -i -s -H 'If-None-Match: $ETAG' '$CACHED_URL'"
echo ""
RESP2=$(curl -i -s -H "If-None-Match: $ETAG" "$CACHED_URL")
echo "$RESP2" | head -n 12

echo ""
echo "=========================================================="
echo "EXPLANATION OF CACHING CONCEPTS (For Evaluator & Viva):"
echo "  1. Full New Request (200 OK):"
echo "     The client has no copy or cache is expired. Server sends"
echo "     full payload + Cache-Control: max-age=60 + ETag."
echo "  2. Conditional Request (304 Not Modified):"
echo "     The client sends 'If-None-Match: <etag>'. The server checks"
echo "     if the content changed. Since it hasn't, the server sends a"
echo "     304 response with zero body bytes, saving LAN bandwidth."
echo "  3. Local Cache Hit (Browser / Client Cache):"
echo "     Within the max-age (60 seconds), the browser will fulfill"
echo "     requests directly from local memory/disk cache without even"
echo "     sending a packet to the network."
echo "=========================================================="
