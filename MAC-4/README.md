# Computer Networks Course Project - Phase 1 (Mac 4 Workspace)

## Machine Role: Backend Server B + Test Client

Welcome to the **Mac 4** project workspace. Everything required for **Phase 1** has been configured, tested, and automated.

---

## ⚡ Quick Start: 3 Steps for Mac 4

### 1. View & Share Your Network Identity (Task A)
```bash
./network/mac4_network_info.sh
```
- **Your IP**: `10.7.12.61`
- **Subnet**: `255.255.224.0`
- **Port**: `3002`
- **Response Header**: `X-Backend: B`

### 2. Start Backend Server B (Task C & Task F)
```bash
./backend/start_backend.sh
```
In a new terminal tab, verify local endpoints:
```bash
./backend/test_backend_local.sh
```

### 3. Configure as Test Client (Tasks B, D, E, F)
Configure your teammate IPs in `network/team_ips.env`, then:
```bash
# Point Mac 4's DNS to Mac 1
./client/setup_dns.sh

# Verify DNS resolution of app.team1.test (Task B)
./client/test_dns.sh

# Install team root CA cert into macOS Keychain (Task E)
./client/install_ca_cert.sh path/to/rootCA.crt

# Test HTTPS connection without -k flag (Task E)
./client/test_https.sh

# Test Round-Robin Load Balancing across Backend A and B (Task D)
./client/test_load_balancing.sh

# Test HTTP Caching (Cache-Control + 304 Not Modified) (Task F)
./client/test_caching.sh

# Demonstrate Phase 1 Failure Scenarios (Section 6.3)
./client/test_failure_scenarios.sh
```

---

## 📁 Project Directory Structure

```text
├── backend/
│   ├── server.js               # Node.js HTTP Backend B server (Port 3002, 0.0.0.0)
│   ├── server.py               # Standalone Python 3 alternative
│   ├── start_backend.sh        # Startup script for Backend B
│   └── test_backend_local.sh   # Comprehensive local endpoint test
├── client/
│   ├── setup_dns.sh            # Configure Mac 4 DNS to Mac 1
│   ├── install_ca_cert.sh      # Trust team Root CA in macOS Keychain
│   ├── test_dns.sh             # Query app.teamX.test via dig/nslookup
│   ├── test_https.sh           # Test HTTPS request without -k
│   ├── test_load_balancing.sh  # Send 10+ requests to verify A/B alternation
│   ├── test_caching.sh         # Test Cache-Control, ETag, and 304 Not Modified
│   └── test_failure_scenarios.sh# Interactive tester for 5 required failure scenarios
├── network/
│   ├── mac4_network_info.sh    # Display Mac 4 IP, Subnet, Gateway, MAC
│   ├── ping_team.sh            # Ping test between all team Macs
│   ├── team_ips.env            # Teammate IP configuration file
│   └── topology_info.txt       # Architecture diagram & IP inventory
└── docs/
    ├── PHASE1_MAC4_GUIDE.md    # Complete walkthrough for Mac 4
    ├── WIRESHARK_CAPTURE_GUIDE.md # Packet capture steps, filters & evidence
    └── VIVA_PREP_MAC4.md       # Individual Viva Q&A specifically for Mac 4
```

---

## 📚 Complete Guides & Documentation
- **Step-by-Step Task Walkthrough**: [PHASE1_MAC4_GUIDE.md](file:///Users/anshikaseth/Desktop/computer%20network/docs/PHASE1_MAC4_GUIDE.md)
- **Wireshark Packet Capture Instructions**: [WIRESHARK_CAPTURE_GUIDE.md](file:///Users/anshikaseth/Desktop/computer%20network/docs/WIRESHARK_CAPTURE_GUIDE.md)
- **Viva Preparation Guide (10 Marks)**: [VIVA_PREP_MAC4.md](file:///Users/anshikaseth/Desktop/computer%20network/docs/VIVA_PREP_MAC4.md)
- **Topology & Service Map**: [topology_info.txt](file:///Users/anshikaseth/Desktop/computer%20network/network/topology_info.txt)
