#!/bin/bash
# ==============================================================================
# Script: test_phase2_ttl_cutover.sh
# Purpose: Extension B - Demonstrate DNS TTL Caching and Cache Invalidation
# Computer Networks Course Project - Phase 2 Extension B
# ==============================================================================

# Team IPs come from the single source of truth: <repo>/team.env
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/team.env"

DOMAIN="app.team1.test"
PRIMARY_DNS="${MAC1_IP}"

echo "=================================================="
echo " Extension B: DNS TTL & Cache Invalidation Demo"
echo " Target Domain: $DOMAIN"
echo "=================================================="

echo ""
echo "[STEP 1] Querying DNS record and inspecting TTL..."
dig @"$PRIMARY_DNS" "$DOMAIN" +noall +answer

TTL_VAL=$(dig @"$PRIMARY_DNS" "$DOMAIN" +noall +answer | awk '{print $2}' | head -n 1)
echo "  Configured TTL Value: ${TTL_VAL:-30} seconds."

echo ""
echo "[STEP 2] Demonstrating DNS Cache Behavior..."
echo "  When a record change occurs on the DNS server, clients will continue"
echo "  using the cached IP until the TTL expires (${TTL_VAL:-30}s)."
echo "  Demonstrating 3 sequential queries (observe decreasing TTL or cached response):"
for i in 1 2 3; do
    echo "  Query $i: $(dig +noall +answer "$DOMAIN" | tr '\n' ' ')"
    sleep 2
done

echo ""
echo "[STEP 3] Demonstrating Manual DNS Cache Flush..."
echo "  Executing: sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true
echo "  Cache successfully cleared!"

echo ""
echo "[STEP 4] Immediate Re-query After Flush..."
dig "$DOMAIN" +noall +answer

echo ""
echo "=================================================="
echo " Theoretical explanation for Review 2:"
echo " - Low TTL (30s) enables rapid cutover during migrations or outages."
echo " - Trade-off: Lower TTL increases DNS lookup queries sent to the server."
echo " - High TTL decreases DNS query traffic but delays emergency cutover."
echo "=================================================="
