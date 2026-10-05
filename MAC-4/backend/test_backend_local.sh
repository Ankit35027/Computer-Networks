#!/usr/bin/env bash
# ==============================================================================
# Local Health & Endpoint Verification for Backend Server B (Mac 4)
# Tests: /, /api/status, /api/cached, and 304 conditional request
# ==============================================================================

PORT=3002
BASE_URL="http://127.0.0.1:${PORT}"

echo "=========================================================="
echo " Testing Local Backend Server B on port $PORT"
echo "=========================================================="

# Check if server is running
if ! nc -z 127.0.0.1 $PORT 2>/dev/null; then
  echo "[!] Server is NOT running on port $PORT."
  echo "    Please start it first: ./backend/start_backend.sh"
  exit 1
fi

echo -e "\n[1] Testing GET /"
curl -s -i "${BASE_URL}/" | head -n 15

echo -e "\n----------------------------------------------------------"
echo "[2] Testing GET /api/status (Task C)"
curl -s -i "${BASE_URL}/api/status"

echo -e "\n----------------------------------------------------------"
echo "[3] Testing GET /api/cached (Task F - Fresh Request)"
CACHE_RESP=$(curl -s -i "${BASE_URL}/api/cached")
echo "$CACHE_RESP" | head -n 12

ETAG=$(echo "$CACHE_RESP" | grep -i "etag:" | awk '{print $2}' | tr -d '\r')
echo -e "\n[DEBUG] Extracted ETag: $ETAG"

echo -e "\n----------------------------------------------------------"
echo "[4] Testing GET /api/cached with If-None-Match (Task F - Conditional 304)"
curl -s -i -H "If-None-Match: $ETAG" "${BASE_URL}/api/cached" | head -n 10

echo -e "\n=========================================================="
echo " Local Backend B Verification Complete!"
echo "=========================================================="
