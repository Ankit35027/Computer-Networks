# Computer Networks Course Project — Team 1
## Private Network Service Platform (Two-Phase Implementation)

A fully local, 4-machine private networking platform built from scratch without cloud dependencies. Demonstrates DNS resolution, reverse proxying, TLS termination, load balancing, caching, and packet analysis.

---

## 💻 Machine Roles & Directory Index

| Machine Directory | Hardware Role | LAN IPv4 | Bound Ports | Primary Service |
|---|---|---|---|---|
| **[`MAC-1/`](MAC-1/)** | Primary DNS Server & Client | `10.7.21.249` | `53/UDP`, `53/TCP` | `dnsmasq` DNS Resolver |
| **[`MAC-2/`](MAC-2/)** | Edge Proxy & Load Balancer | `10.7.23.158` | `8443/TCP`, `80/TCP` | `nginx` + TLS 1.3 Reverse Proxy |
| **[`MAC-3/`](MAC-3/)** | Backend Application Server A | `10.7.22.2` | `3001/TCP` | Node.js REST API (`server.js`) |
| **[`MAC-4/`](MAC-4/)** | Backend Server B & Client | `10.7.21.68` | `3002/TCP` | Node / Python REST API (`server.js`) |

---

## 📂 Repository Structure

```text
Computer-Networks/
├── README.md                          # Master Project Overview & Team Operations Guide
├── ARCHITECTURE.md                    # Master Architecture Doc: Topology, Sequence Flow & OSI Mapping
│
├── docs/                              # Global Shared Documentation
│   ├── CN_Project_Doc_complete.md      # Course Project Specification & Rubric
│   ├── PHASE2_REPORT.md               # Integrated Phase 2 Resilience & Failover Report
│   └── PENDING_TASKS_BY_MACHINE.md     # Team Responsibilities & Action Plan
│
├── MAC-1/                             # Mac 1: Primary DNS Server & Client
│   ├── configs/                       # dnsmasq.conf (Port 53, TTL 30s)
│   ├── scripts/                       # LAN verify, DNS install, test, & Wireshark capture scripts
│   └── evidence/                      # Captures (.pcapng), Screenshots (SS01-SS14), & Logs
│
├── MAC-2/                             # Mac 2: Edge Reverse Proxy & Load Balancer
│   ├── configs/                       # nginx.conf (Round-Robin load balancing & TLS)
│   ├── certs/                         # OpenSSL TLS Certificates & Keys (CN=app.team1.test)
│   ├── scripts/                       # Nginx reload & test scripts
│   └── evidence/                      # Nginx access/error logs & evidence captures
│
├── MAC-3/                             # Mac 3: Backend Server A (Port 3001)
│   ├── server.js                      # Node.js REST API (Port 3001, Header: X-Backend: A)
│   ├── package.json                   # Dependencies
│   ├── configs/                       # Backup DNS & isolation firewall rules (pf)
│   └── evidence/                      # Screenshots & verification logs
│
└── MAC-4/                             # Mac 4: Backend Server B (Port 3002) + Client
    ├── backend/                       # REST API (Port 3002, Header: X-Backend: B)
    ├── client/                        # Automated evaluation test scripts
    ├── certs/                         # CA Root certificate for client trust
    └── network/                       # LAN ping & network discovery scripts
```

---

## 🚀 System Quick Start

### Step 1: Start MAC-1 (Primary DNS)
```bash
cd MAC-1
sudo sh -c 'pkill -f dnsmasq 2>/dev/null; sleep 1; /opt/homebrew/sbin/dnsmasq --conf-file=configs/dnsmasq.conf'
```

### Step 2: Start MAC-3 & MAC-4 (Backends A & B)
```bash
# On MAC-3:
cd MAC-3 && node server.js

# On MAC-4:
cd MAC-4/backend && node server.js  # or python3 server.py
```

### Step 3: Start MAC-2 (Edge Proxy)
```bash
cd MAC-2
brew services restart nginx
```

### Step 4: Run Verification from Client (MAC-1 or MAC-4)
```bash
# Test Load Balancing across both backends (A & B alternating)
for i in {1..6}; do
    curl -sk --resolve app.team1.test:8443:10.7.23.158 https://app.team1.test:8443/api/status
    echo ""
done
```
