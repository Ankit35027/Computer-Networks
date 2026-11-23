#!/bin/bash
# ==============================================================================
# Script: test_phase2_backup_dns.sh
# Purpose: Extension A - Verify Backup DNS Resolver Failover from Client
# Computer Networks Course Project - Phase 2 Extension A
# ==============================================================================

PRIMARY_DNS="10.7.21.249"
BACKUP_DNS="10.7.22.2"
DOMAIN="app.team1.test"

echo "=================================================="
echo " Extension A: Backup DNS Resolver Demonstration"
echo " Target Domain: $DOMAIN"
echo " Primary DNS  : $PRIMARY_DNS (Mac 1)"
echo " Backup DNS   : $BACKUP_DNS (Mac 3)"
echo "=================================================="

echo ""
echo "[STEP 1] Direct Query to Primary DNS ($PRIMARY_DNS)..."
PRIMARY_OUT=$(dig @"$PRIMARY_DNS" "$DOMAIN" +noall +answer +stats 2>&1)
if echo "$PRIMARY_OUT" | grep -q "10.7.23.158"; then
    echo "  [SUCCESS] Primary DNS resolved $DOMAIN to 10.7.23.158!"
    echo "$PRIMARY_OUT" | sed 's/^/    /'
else
    echo "  [OFFLINE / UNREACHABLE] Primary DNS did not respond."
fi

echo ""
echo "[STEP 2] Direct Query to Backup DNS ($BACKUP_DNS)..."
BACKUP_OUT=$(dig @"$BACKUP_DNS" "$DOMAIN" +noall +answer +stats 2>&1)
if echo "$BACKUP_OUT" | grep -q "10.7.23.158"; then
    echo "  [SUCCESS] Backup DNS resolved $DOMAIN to 10.7.23.158!"
    echo "$BACKUP_OUT" | sed 's/^/    /'
else
    echo "  [FAIL] Backup DNS did not respond on $BACKUP_DNS:53."
fi

echo ""
echo "[STEP 3] Client System Resolver Query (Operating System Failover)..."
echo "  Querying system resolver via standard dig without @server argument..."
SYS_OUT=$(dig "$DOMAIN" +noall +answer +stats 2>&1)
if echo "$SYS_OUT" | grep -q "10.7.23.158"; then
    echo "  [PASS] System resolved $DOMAIN successfully!"
    echo "$SYS_OUT" | sed 's/^/    /'
else
    echo "  [FAIL] System resolution failed."
fi

echo ""
echo "=================================================="
echo " Observation for Review 2:"
echo " When Mac 1 primary dnsmasq is stopped (sudo pkill dnsmasq),"
echo " Step 1 fails, but Step 2 and Step 3 succeed via Mac 3 backup DNS!"
echo "=================================================="
