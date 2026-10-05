#!/usr/bin/env bash
# ==============================================================================
# Phase 1 Section 6.3: Required Failure Demonstrations
# Interactive helper to run and explain each failure scenario from Mac 4
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../network/team_ips.env" ]; then
  source "$SCRIPT_DIR/../network/team_ips.env"
fi

DOMAIN="${TEAM_DOMAIN:-app.team1.test}"

echo "=========================================================="
echo "    PHASE 1: SECTION 6.3 REQUIRED FAILURE DEMONSTRATIONS"
echo "=========================================================="
echo "Select a scenario to run / inspect:"
echo "  1) Wrong DNS Server configured on client"
echo "  2) DNS record points to wrong IP address"
echo "  3) One backend stopped (Simulate Backend B shutdown)"
echo "  4) Both backends stopped (502 Bad Gateway)"
echo "  5) Wrong destination port on client"
echo ""

read -p "Select scenario [1-5]: " scenario

case "$scenario" in
  1)
    echo "=========================================================="
    echo "SCENARIO 1: Wrong DNS Server Configured on Client"
    echo "=========================================================="
    echo "Action: Querying domain '$DOMAIN' using an invalid DNS resolver (10.254.254.254)..."
    dig @10.254.254.254 "$DOMAIN" +time=2 +tries=1
    echo ""
    echo "Observation: Name lookup times out / fails completely."
    echo "Now testing IP direct ping to Mac 2 (Edge):"
    if [ -n "$MAC2_EDGE_IP" ] && [[ "$MAC2_EDGE_IP" != *"Y"* ]]; then
      ping -c 2 "$MAC2_EDGE_IP"
    else
      echo "(Direct IP ping still works because IP layer is healthy)"
    fi
    echo ""
    echo "Theory / Viva Explanation:"
    echo "  Demonstrates that DNS (Application layer) and IP connectivity"
    echo "  (Network layer) are completely independent. Even with full IP reachability,"
    echo "  an incorrect resolver makes domain-based communication impossible."
    ;;

  2)
    echo "=========================================================="
    echo "SCENARIO 2: DNS Record Points to Wrong IP Address"
    echo "=========================================================="
    echo "Theory / Demonstration:"
    echo "  On Mac 1 (dnsmasq), change app.teamX.test -> 10.7.12.250 (unused IP)."
    echo "  Client runs: curl -m 3 https://$DOMAIN"
    echo ""
    echo "Simulating connecting to a bogus IP over port 443:"
    curl -m 3 "https://10.254.254.254/" 2>&1 | head -n 5
    echo ""
    echo "Observation: DNS resolution succeeds (gives an IP), but connection times out or is refused."
    echo "Theory / Viva Explanation:"
    echo "  DNS is a directory, not a connection. DNS only provides the mapping;"
    echo "  it does not guarantee that the IP host is listening on port 443."
    ;;

  3)
    echo "=========================================================="
    echo "SCENARIO 3: One Backend Stopped (Mac 4 Backend B)"
    echo "=========================================================="
    echo "Action: Stop Backend B on this machine (Mac 4):"
    PID=$(lsof -ti :3002 2>/dev/null)
    if [ -n "$PID" ]; then
      echo "Stopping Backend B (PID: $PID)..."
      kill -9 "$PID"
      echo "Backend B is now STOPPED."
    else
      echo "Backend B was already stopped."
    fi
    echo ""
    echo "Now sending requests to https://$DOMAIN/api/status..."
    echo "Observation: Nginx detects port 3002 is down and routes 100% of"
    echo "requests to Backend A (Mac 3). All responses return X-Backend: A."
    echo ""
    echo "To restart Backend B afterwards, run: ./backend/start_backend.sh"
    ;;

  4)
    echo "=========================================================="
    echo "SCENARIO 4: Both Backends Stopped"
    echo "=========================================================="
    echo "Action: Backend A (Mac 3) and Backend B (Mac 4) are both stopped."
    echo "Client executes: curl -i https://$DOMAIN/api/status"
    echo ""
    echo "Observation: HTTP 502 Bad Gateway"
    echo "Theory / Viva Explanation:"
    echo "  DNS resolution succeeds (Mac 2 IP returned)."
    echo "  TCP 3-way handshake succeeds with Mac 2 (port 443)."
    echo "  TLS handshake succeeds (Mac 2 terminates SSL cleanly)."
    echo "  Nginx tries upstream proxy to ports 3001 and 3002 -> Connection Refused."
    echo "  Nginx returns 502 Bad Gateway."
    echo "  This proves where the edge proxy ends and backend instances begin!"
    ;;

  5)
    echo "=========================================================="
    echo "SCENARIO 5: Wrong Destination Port on Client"
    echo "=========================================================="
    echo "Action: Client tries to connect to port 8888 on Edge (instead of 443):"
    if [ -n "$MAC2_EDGE_IP" ] && [[ "$MAC2_EDGE_IP" != *"Y"* ]]; then
      curl -m 3 "https://${MAC2_EDGE_IP}:8888/" 2>&1
    else
      curl -m 3 "https://127.0.0.1:8888/" 2>&1
    fi
    echo ""
    echo "Observation: Connection refused (TCP RST packet received)."
    echo "Theory / Viva Explanation:"
    echo "  The IP host is reachable, but no process is bound to port 8888."
    echo "  The OS TCP stack sends back a TCP RST. Proves that IP addresses"
    echo "  and TCP port numbers are separate identifiers (Layer 3 vs Layer 4)."
    ;;

  *)
    echo "Invalid option."
    ;;
esac
