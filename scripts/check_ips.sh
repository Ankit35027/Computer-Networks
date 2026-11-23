#!/bin/bash
# ==============================================================================
# check_ips.sh – verify that config files agree with team.env
# Run from anywhere:  ./scripts/check_ips.sh
# Configs (dnsmasq / nginx) cannot read team.env, so they hold literal IPs.
# This script tells you which ones are stale after a DHCP change.
# Optional: ./scripts/check_ips.sh --live  also compares team.env with THIS Mac's en0 IP.
# ==============================================================================
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/team.env"
FAIL=0

check() {  # check <file> <expected-ip> <grep-pattern> <description>
    local file="$ROOT/$1" ip="$2" pat="$3" desc="$4"
    if [ ! -f "$file" ]; then echo "  [SKIP] $1 (missing)"; return; fi
    local lines; lines=$(grep -E "$pat" "$file" | grep -v '^\s*#')
    if [ -z "$lines" ]; then echo "  [WARN] $1: no line matches '$pat'"; return; fi
    if echo "$lines" | grep -vq -- "$ip"; then
        echo "  [STALE] $1 ($desc) should use $ip:"; echo "$lines" | grep -v -- "$ip" | sed 's/^/          /'; FAIL=1
    else
        echo "  [OK]    $1 ($desc) -> $ip"
    fi
}

echo "team.env: MAC1=$MAC1_IP  MAC2=$MAC2_IP  MAC3=$MAC3_IP  MAC4=$MAC4_IP"
check MAC-1/configs/dnsmasq.conf        "$MAC2_IP" '^address=/(app\.|api\.)?team1\.test/' "primary DNS records -> edge"
check MAC-3/configs/dnsmasq_backup.conf "$MAC2_IP" '^address=/(app\.|api\.)?team1\.test/' "backup DNS records -> edge"
check MAC-2/configs/nginx.conf          "$MAC3_IP" 'server .*:3001'                   "upstream Backend A"
check MAC-2/configs/nginx.conf          "$MAC4_IP" 'server .*:3002'                   "upstream Backend B"
check MAC-3/configs/nginx.conf          "$MAC3_IP" 'server .*:3001'                   "standby upstream Backend A"
check MAC-3/configs/nginx.conf          "$MAC4_IP" 'server .*:3002'                   "standby upstream Backend B"

if [ "$1" = "--live" ]; then
    ME=$(ipconfig getifaddr en0 2>/dev/null)
    echo "This Mac ($(hostname -s)) en0 = ${ME:-none}"
    echo "$MAC1_IP $MAC2_IP $MAC3_IP $MAC4_IP" | grep -qw -- "$ME" \
        && echo "  [OK]    this IP is listed in team.env" \
        || { echo "  [STALE] this Mac's IP is NOT in team.env - update team.env"; FAIL=1; }
fi

[ $FAIL -eq 0 ] && echo "All checked configs match team.env." || echo "Fix the STALE lines above, commit, and git pull on the affected Macs."
exit $FAIL
