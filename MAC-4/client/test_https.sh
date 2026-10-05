#!/usr/bin/env bash
# ==============================================================================
# Task E: Test HTTPS / TLS Access to app.teamX.test
# Validates: TLS Handshake, Certificate Trust (no -k flag), and Status 200
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../network/team_ips.env" ]; then
  source "$SCRIPT_DIR/../network/team_ips.env"
fi

DOMAIN="${1:-${TEAM_DOMAIN:-app.team1.test}}"
URL="https://${DOMAIN}"

echo "=========================================================="
echo "          TASK E: HTTPS / TLS CONNECTION TEST"
echo "=========================================================="
echo "Connecting to: $URL"
echo ""

echo "--- [1] Full TLS Handshake & Header Inspection (curl -v) ---"
# Note: No -k flag! Must use trusted local root CA
curl -v -s -o /dev/null "$URL" 2>&1 | grep -E "Connected to|SSL connection|Server certificate|issuer:|subject:|HTTP/"

echo ""
echo "--- [2] Testing GET / Endpoint ---"
curl -s "$URL/"
echo ""

echo "--- [3] Testing GET /api/status Endpoint ---"
curl -s "$URL/api/status"
echo ""

echo "=========================================================="
echo "Notice the 'X-Backend' header received from the Edge Proxy!"
echo "=========================================================="
