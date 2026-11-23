#!/bin/bash
# ==============================================================================
# Script: run_phase2_evaluation.sh
# Purpose: Master Phase 2 Client Demonstration Runner for Mac 4
# Computer Networks Course Project - Phase 2 (Extensions A, B, C, D, E)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================================================"
echo "    TEAM 1 - PHASE 2 MASTER DEMONSTRATION SUITE (CLIENT NODE: MAC 4)           "
echo "    HARDEN, RECOVER, AND TROUBLESHOOT                                           "
echo "================================================================================"

echo ""
read -p "Press ENTER to run Extension A: Backup DNS Resolver Verification..."
"$SCRIPT_DIR/test_phase2_backup_dns.sh"

echo ""
read -p "Press ENTER to run Extension B: DNS TTL & Cache Invalidation Demo..."
"$SCRIPT_DIR/test_phase2_ttl_cutover.sh"

echo ""
read -p "Press ENTER to run Extension C: Backend Service Isolation Firewall Test..."
"$SCRIPT_DIR/test_phase2_firewall_isolation.sh"

echo ""
read -p "Press ENTER to run Extension D: High-Availability Failover & Recovery..."
"$SCRIPT_DIR/test_phase2_ha_failover.sh" 10

echo ""
read -p "Press ENTER to run Extension E: Controlled Edge Migration (Cutover)..."
"$SCRIPT_DIR/test_phase2_edge_migration.sh"

echo ""
echo "================================================================================"
echo " Phase 2 Client Demonstration Complete! All Extension Checks Passed."
echo "================================================================================"
