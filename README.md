# Computer Networks Course Project — Team 1
## Private Network Service Platform (Phase 1 & Phase 2 Implementation)

A fully local, 4-machine private networking platform built from scratch without cloud dependencies.
- **Phase 1 (Build & Observe)**: Private DNS resolution, reverse proxying, TLS 1.3 termination, load balancing, caching, and Wireshark packet analysis.
- **Phase 2 (Harden, Recover, and Troubleshoot)**: Multi-resolver backup DNS (Ext A), DNS TTL cutover (Ext B), Packet Filter service isolation (Ext C), high-availability upstream failover (Ext D), standby edge cutover (Ext E), and systematic OSI fault diagnosis (Ext F).

---

## 💻 Machine Roles & Directory Index

| Machine Directory | Hardware Role | LAN IPv4 | Bound Ports | Primary Services |
|---|---|---|---|---|
| **[`MAC-1/`](MAC-1/)** | Primary DNS Server & Client | `10.7.21.249` | `53/UDP`, `53/TCP` | `dnsmasq` DNS Resolver (TTL: 30s) |
| **[`MAC-2/`](MAC-2/)** | Edge Proxy & Load Balancer | `10.7.23.158` | `8443/TCP`, `80/TCP` | `nginx` + TLS 1.3 Reverse Proxy & HA Passive Health Monitor |
| **[`MAC-3/`](MAC-3/)** | Backend A, Backup DNS & Standby Edge | `10.7.22.2` | `3001/TCP`, `53/UDP`, `8443/TCP` | Node.js REST API (`server.js`), Backup `dnsmasq`, Standby `nginx` |
| **[`MAC-4/`](MAC-4/)** | Backend B & Client Node | `10.7.21.68` | `3002/TCP` | Node / Python REST API (`server.js`), Automated Evaluation Suite |

- **Subnet Range**: `10.7.0.0/19` (Netmask: `255.255.224.0`, Gateway: `10.7.0.1`)
- **Domain Names**: `app.team1.test`, `api.team1.test`, `team1.test`

---

## 📂 Repository Structure

```text
Computer-Networks/
├── README.md                          # Master Project Overview & Team Operations Guide
├── ARCHITECTURE.md                    # Master Topology, Sequence Flows, OSI & Resilience Mappings
│
├── docs/                              # Global Shared Documentation
│   ├── CN_Project_Doc_complete.md      # Course Project Specification & Rubric
│   ├── PHASE2_REPORT.md               # Integrated Phase 2 Hardening, Failover & Viva Report
│   └── PENDING_TASKS_BY_MACHINE.md     # Team Responsibilities & 11-Step Demonstration Sequence
│
├── MAC-1/                             # Mac 1: Primary DNS Server & Client
│   ├── configs/                       # dnsmasq.conf (Port 53, TTL 30s)
│   ├── scripts/                       # Phase 1 & Phase 2 DNS lifecycle & cutover scripts
│   ├── docs/                          # Architecture doc & Phase 2 Mac 1 Guide
│   └── evidence/                      # Captures (.pcapng), Screenshots (SS01-SS14), & Logs
│
├── MAC-2/                             # Mac 2: Edge Reverse Proxy & Load Balancer
│   ├── configs/                       # nginx.conf, nginx_ha.conf, pf_backend_isolation.conf
│   ├── certs/                         # OpenSSL TLS Certificates & Keys (CN=app.team1.test)
│   ├── scripts/                       # Start scripts, Phase 2 master runner, and troubleshoot tool
│   └── evidence/                      # Nginx access/error logs & evidence captures (.pcap)
│
├── MAC-3/                             # Mac 3: Backend A (Port 3001), Backup DNS & Standby Edge
│   ├── server.js                      # Node.js REST API (Port 3001, Header: X-Backend: A)
│   ├── start-all.sh                   # Master service starter for Mac 3
│   ├── configs/                       # dnsmasq_backup.conf, pf_backend_isolation.conf, nginx.conf
│   ├── scripts/                       # Local Phase 2 verification script
│   ├── certs/                         # TLS certificates for standby edge
│   └── docs/                          # Phase 2 Mac 3 Operational Guide
│
└── MAC-4/                             # Mac 4: Backend B (Port 3002) + Primary Client Node
    ├── backend/                       # REST API (Port 3002, Header: X-Backend: B)
    ├── configs/                       # pf_backend_isolation.conf, pf_rollback.conf
    ├── client/                        # Complete Phase 1 & Phase 2 Automated Test Suites
    ├── certs/                         # CA Root certificate for client trust
    ├── docs/                          # Mac 4 Guide, Wireshark Guide, and Phase 2 Viva Prep
    └── evidence/                      # Full Phase 1 & Phase 2 Screenshots & Logs
```

---

## 🚀 Quick Start: Running Phase 2 on the Network

### Step 1: Start MAC-1 (Primary DNS)
```bash
cd MAC-1
sudo ./scripts/phase2_dns_failover_demo.sh start
```

### Step 2: Start MAC-3 (Backend A, Backup DNS & PF Firewall)
```bash
cd MAC-3
sudo ./start-all.sh
```

### Step 3: Start MAC-4 (Backend B & Apply PF Firewall)
```bash
# In one terminal: Start Backend B
cd MAC-4 && ./backend/start_backend.sh

# In another terminal: Apply PF Firewall Isolation
cd MAC-4 && sudo pfctl -e -f configs/pf_backend_isolation.conf
```

### Step 4: Start MAC-2 (Edge Proxy with HA Failover)
```bash
cd MAC-2
./scripts/start_nginx.sh start
```

### Step 5: Run Phase 2 Automated Demonstration from MAC-4 (Client)
```bash
cd MAC-4
# Configure multi-resolver (Primary Mac 1 + Secondary Mac 3)
./client/setup_phase2_dns.sh

# Run interactive Phase 2 test suite
./client/run_phase2_evaluation.sh
```

---

## 🎯 Phase 2 Extension Summary

1. **Extension A (Backup DNS Resolver)**: Client queries resolve seamlessly through Mac 3 (`10.7.22.2`) when Mac 1 (`10.7.21.249`) is killed.
2. **Extension B (DNS TTL & Cache Invalidation)**: Visible 30s TTL on DNS records; manual cache invalidation via `dscacheutil -flushcache`.
3. **Extension C (Service Isolation)**: Direct client connections to ports 3001 and 3002 are blocked by `pfctl`; only Mac 2 (`10.7.23.158`) can reach backends.
4. **Extension D (High-Availability Failover)**: When Backend A crashes, Nginx instantly redirects traffic to Backend B with zero dropped requests.
5. **Extension E (Controlled Edge Migration)**: DNS cutover to Standby Edge on Mac 3 without client reconfiguration.
6. **Extension F (Fault Troubleshooting)**: Multi-layer diagnostic tool isolating DNS, TCP, TLS, and Application issues.
