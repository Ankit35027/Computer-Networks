#!/usr/bin/env bash
# ==============================================================================
# Task D: Verify Round-Robin Load Balancing across Backend A and Backend B
# Sends repeated requests to https://app.teamX.test/api/status
# Inspects 'X-Backend' header to prove alternating distribution
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../network/team_ips.env" ]; then
  source "$SCRIPT_DIR/../network/team_ips.env"
fi

DOMAIN="${1:-${TEAM_DOMAIN:-app.team1.test}}"
NUM_REQUESTS="${2:-10}"
URL="https://${DOMAIN}/api/status"

echo "=========================================================="
echo "          TASK D: LOAD BALANCING VERIFICATION"
echo "=========================================================="
echo "Sending $NUM_REQUESTS requests to: $URL"
echo "Observing 'X-Backend' response header..."
echo ""

COUNT_A=0
COUNT_B=0
COUNT_ERR=0

for i in $(seq 1 "$NUM_REQUESTS"); do
  HEADER=$(curl -s -i "$URL" | grep -i "x-backend:" | tr -d '\r')
  BACKEND_VAL=$(echo "$HEADER" | awk '{print $2}')

  if [ "$BACKEND_VAL" == "A" ]; then
    echo "Request #$i: Served by Backend [ A ] (Mac 3)"
    ((COUNT_A++))
  elif [ "$BACKEND_VAL" == "B" ]; then
    echo "Request #$i: Served by Backend [ B ] (Mac 4 - This machine!)"
    ((COUNT_B++))
  else
    echo "Request #$i: ERROR or Unknown backend header ($HEADER)"
    ((COUNT_ERR++))
  fi
  sleep 0.2
done

echo ""
echo "=========================================================="
echo "LOAD BALANCING SUMMARY:"
echo "  Total Requests : $NUM_REQUESTS"
echo "  Backend A (Mac 3) : $COUNT_A requests"
echo "  Backend B (Mac 4) : $COUNT_B requests"
echo "  Errors            : $COUNT_ERR"
echo "=========================================================="
if [ $COUNT_A -gt 0 ] && [ $COUNT_B -gt 0 ]; then
  echo "[SUCCESS] Both backends are actively serving traffic via Nginx Edge!"
fi
