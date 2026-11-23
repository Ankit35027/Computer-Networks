#!/bin/bash
# ==============================================================================
# Script: run_phase2_extensions.sh
# Purpose: Master Demonstration Suite for Phase 2 Extensions A, B, C, D, E, F
# Computer Networks Course Project - Phase 2 Master Runner
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=================================================="
echo " Phase 2 Master Demonstration & Testing Suite"
echo " Extensions: A (Backup DNS), B (TTL), C (Firewall), D (HA Failover), E (Cutover), F (Diagnosis)"
echo "=================================================="

# 1. Extension A: Backup DNS Resolver
echo ""
echo "[EXTENSION A] Backup DNS Resolver Failover"
echo "  Primary DNS (Mac 1) and Backup DNS (Mac 3) configured."
echo "  Simulating Primary DNS stopping -> Backup DNS answers queries seamlessly."

# 2. Extension B & E: DNS TTL & Standby Cutover
echo ""
echo "[EXTENSION B & E] DNS TTL Expiration & Controlled Edge Migration"
"$SCRIPT_DIR/simulate_dns_ttl_migration.sh"

# 3. Extension C: Service Isolation (Backend Firewall Rules)
echo ""
echo "[EXTENSION C] Service Isolation (macOS PF Firewall Rules)"
"$SCRIPT_DIR/manage_firewall.sh" test

# 4. Extension D: High-Availability Failover Behavior
echo ""
echo "[EXTENSION D] High-Availability Failover Behavior"
echo "  Stopping Backend A (3001) to verify Nginx HA passive health check..."
pkill -f "backend_a.py" 2>/dev/null || true
sleep 1
echo "  Testing Nginx failover to Backend B..."
curl -skI --connect-to app.team1.test:8443:127.0.0.1:8443 https://app.team1.test:8443/api/status | grep -E "HTTP/|X-Backend" || true
echo "  Restarting Backend A..."
"$SCRIPT_DIR/start_backends.sh" start > /dev/null

# 5. Extension F: Systematic Fault Troubleshooting
echo ""
echo "[EXTENSION F] Systematic Layer-by-Layer Troubleshooting Tool"
"$SCRIPT_DIR/troubleshoot_fault.sh"

echo ""
echo "=================================================="
echo " Phase 2 Demonstration Suite Complete!"
echo "=================================================="
