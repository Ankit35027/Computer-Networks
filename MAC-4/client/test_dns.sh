#!/usr/bin/env bash
# ==============================================================================
# Task B: Verify Private DNS Resolution from Mac 4
# Tests: app.teamX.test and api.teamX.test
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../network/team_ips.env" ]; then
  source "$SCRIPT_DIR/../network/team_ips.env"
fi

DOMAIN="${1:-${TEAM_DOMAIN:-app.team1.test}}"

echo "=========================================================="
echo "          TASK B: DNS RESOLUTION TEST FROM MAC 4"
echo "=========================================================="
echo "Testing target domain: $DOMAIN"
echo ""

echo "--- [1] Testing with dig (System Default Resolver) ---"
dig "$DOMAIN" +noall +answer +stats
echo ""

if [ -n "$MAC1_DNS_IP" ] && [[ "$MAC1_DNS_IP" != *"X"* ]]; then
  echo "--- [2] Directly Querying Mac 1 DNS Server ($MAC1_DNS_IP) ---"
  dig "@$MAC1_DNS_IP" "$DOMAIN" +noall +answer +stats
  echo ""
fi

echo "--- [3] Testing with nslookup ---"
nslookup "$DOMAIN"
echo ""

echo "=========================================================="
echo "Check: Did the query return the private IP of Mac 2 (Edge Nginx)?"
echo "If yes, Task B DNS resolution is working perfectly!"
echo "=========================================================="
