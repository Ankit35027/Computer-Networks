#!/usr/bin/env bash
# ==============================================================================
# Task A: Team Reachability Ping Test
# Verifies ICMP connectivity between Mac 4 and all teammates (Mac 1, 2, 3)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/team_ips.env" ]; then
  source "$SCRIPT_DIR/team_ips.env"
fi

echo "=========================================================="
echo "          TASK A: TEAM CONNECTIVITY PING TEST"
echo "=========================================================="

test_ping() {
  local role="$1"
  local ip="$2"

  echo -n "[*] Testing $role ($ip)... "
  if [[ "$ip" == *"X"* ]] || [[ "$ip" == *"Y"* ]] || [[ "$ip" == *"Z"* ]] || [ -z "$ip" ]; then
    echo "SKIPPED (IP not yet configured in network/team_ips.env)"
    return
  fi

  ping -c 3 -W 1000 "$ip" > /tmp/ping_output.txt 2>&1
  if [ $? -eq 0 ]; then
    local rtt=$(grep 'avg' /tmp/ping_output.txt | awk -F '/' '{print $5}')
    echo "SUCCESS! (Avg RTT: ${rtt} ms)"
  else
    echo "FAILED! (Check Wi-Fi connection, IP address, or macOS firewall)"
  fi
}

test_ping "Mac 1 (DNS Server)      " "$MAC1_DNS_IP"
test_ping "Mac 2 (Edge Nginx)      " "$MAC2_EDGE_IP"
test_ping "Mac 3 (Backend A)       " "$MAC3_BACKEND_A_IP"
test_ping "Mac 4 (Self/Loopback)   " "127.0.0.1"

echo "=========================================================="
echo "Tip: Make sure all Macs are on the same Wi-Fi SSID and client"
echo "isolation (AP isolation) is disabled on the router."
echo "=========================================================="
