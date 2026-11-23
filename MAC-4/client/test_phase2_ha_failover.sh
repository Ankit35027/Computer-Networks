#!/bin/bash
# ==============================================================================
# Script: test_phase2_ha_failover.sh
# Purpose: Extension D - Continuous Request Stream to Observe HA Failover & Recovery
# Computer Networks Course Project - Phase 2 Extension D
# ==============================================================================

URL="https://app.team1.test:8443/api/status"
TOTAL_REQUESTS="${1:-10}"

echo "=================================================="
echo " Extension D: Nginx High-Availability Failover Test"
echo " Endpoint: $URL"
echo " Sending $TOTAL_REQUESTS requests..."
echo "=================================================="

A_COUNT=0
B_COUNT=0
FAIL_COUNT=0

for i in $(seq 1 "$TOTAL_REQUESTS"); do
    RESP=$(curl -sk -w "\n%{http_code}" "$URL" 2>/dev/null || echo "FAILED\n000")
    HTTP_CODE=$(echo "$RESP" | tail -n 1)
    BODY=$(echo "$RESP" | head -n -1)
    
    BACKEND=$(echo "$BODY" | grep -o '"backend": *"[^"]*"' | cut -d'"' -f4 || echo "None")
    
    if [ "$HTTP_CODE" == "200" ]; then
        if [ "$BACKEND" == "A" ]; then
            ((A_COUNT++))
            echo "Request #$i: HTTP $HTTP_CODE | Serviced by Backend A [10.7.22.2:3001]"
        elif [ "$BACKEND" == "B" ]; then
            ((B_COUNT++))
            echo "Request #$i: HTTP $HTTP_CODE | Serviced by Backend B [10.7.21.68:3002]"
        else
            echo "Request #$i: HTTP $HTTP_CODE | Serviced by Backend: $BACKEND"
        fi
    else
        ((FAIL_COUNT++))
        echo "Request #$i: HTTP $HTTP_CODE | REQUEST FAILED!"
    fi
    sleep 0.5
done

echo ""
echo "--------------------------------------------------"
echo " Execution Summary:"
echo " Total Requests: $TOTAL_REQUESTS"
echo " Backend A Responses: $A_COUNT"
echo " Backend B Responses: $B_COUNT"
echo " Failed Requests    : $FAIL_COUNT"
echo "--------------------------------------------------"

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo " [PASS] 100% Availability! Zero dropped requests."
    if [ "$A_COUNT" -gt 0 ] && [ "$B_COUNT" -gt 0 ]; then
        echo " [INFO] Normal State: Traffic balanced across both Backend A and Backend B."
    elif [ "$A_COUNT" -eq 0 ] && [ "$B_COUNT" -gt 0 ]; then
        echo " [INFO] Failover State: Backend A is down; Nginx transparently routed 100% traffic to Backend B!"
    fi
else
    echo " [WARNING] Detected $FAIL_COUNT failed requests. Check upstream health."
fi
echo "=================================================="
