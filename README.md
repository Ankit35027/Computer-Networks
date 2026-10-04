# Computer Networks Course Project - Phase 1 Build & Observe
## Mac 2 Implementation & Demonstration Guide

Welcome to the **Mac 2 (Edge Reverse Proxy & Load Balancer)** project bundle. This directory contains all source code, configurations, SSL certificates, helper scripts, architecture documentation, and test logs for Phase 1.

---

## 1. Project Directory Structure

```
computer network/
├── README.md                              # This master guide and evaluation cheat sheet
├── ARCHITECTURE.md                        # Network topology diagram, IP table, and protocol layer mapping
├── configs/
│   ├── nginx.conf                         # Standalone Nginx configuration for Mac 2 Edge Proxy & Load Balancer
│   └── dnsmasq.conf                       # Reference DNS server configuration for Mac 1
├── backends/
│   ├── backend_a.py                       # REST Application Server A (Port 3001, Header: X-Backend: A)
│   └── backend_b.py                       # REST Application Server B (Port 3002, Header: X-Backend: B)
├── certs/
│   ├── generate_certs.sh                  # Shell script to generate local Root CA and SAN SSL Certificates
│   ├── openssl_san.cnf                    # OpenSSL configuration with Subject Alternative Names (*.team1.test)
│   ├── ca.crt                             # Local Root CA Certificate (to be trusted by clients)
│   ├── server.crt                         # Nginx SSL Certificate
│   └── server.key                         # Nginx SSL Private Key
├── scripts/
│   ├── get_network_info.sh                # LAN Network Interface & IP/MAC discovery script (Task A)
│   ├── start_backends.sh                  # Startup & lifecycle manager for Backend Servers A & B (Task C)
│   ├── start_nginx.sh                     # Startup & lifecycle manager for Nginx (Tasks D & E)
│   ├── test_endpoints.sh                  # Automated test suite (DNS, HTTPS, Load Balancing, Caching, HTTP/2)
│   └── run_failure_tests.sh               # Section 6.3 Mandatory Failure Demonstrations simulator
└── evidence/
    ├── packet_capture_guide.md            # Wireshark / tcpdump protocol flow guide (Task G)
    └── test_logs/                         # Saved execution logs and evidence exports
```

---

## 2. Quick Start Execution Guide for Mac 2

### Step 1: Install Nginx (if not already installed)
```bash
brew install nginx
```

### Step 2: Discover LAN Network Information (Task A)
Run the network discovery script to collect Mac 2's IP address, active interface, MAC address, and subnet mask:
```bash
./scripts/get_network_info.sh
```

### Step 3: Generate TLS/SSL Certificates (Task E)
Certificates are pre-generated in `certs/`, but you can regenerate them anytime:
```bash
./certs/generate_certs.sh
```
To trust `ca.crt` in macOS Keychain (so curl & browsers connect over HTTPS with zero warnings):
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/ca.crt
```

### Step 4: Add Domain Resolution Entry on Mac 2
To map `app.team1.test` to `127.0.0.1` or Mac 2's LAN IP locally:
```bash
echo "127.0.0.1 app.team1.test api.team1.test team1.test" | sudo tee -a /etc/hosts
```

### Step 5: Start Backend Servers A & B (Task C & F)
```bash
./scripts/start_backends.sh start
```
Verify backends are running:
```bash
./scripts/start_backends.sh status
```

### Step 6: Start Nginx Edge Reverse Proxy (Task D & E)
```bash
./scripts/start_nginx.sh start
```

### Step 7: Execute Comprehensive Automated Test Suite (Tasks A-G)
```bash
./scripts/test_endpoints.sh
```

---

## 3. Demonstration Sequence (Section 8 Checklist)

| Step # | Evaluator Checklist Step | Command / Action | Expected Result |
|--------|--------------------------|------------------|-----------------|
| **1** | Show topology and IP inventory | View `ARCHITECTURE.md` | Clear network diagram, IP table, and machine roles shown |
| **2** | Confirm LAN ping reachability | `./scripts/get_network_info.sh` | Show active interface IP and ping Mac 1 / 3 / 4 |
| **3** | Resolve private domain from client | `dig app.team1.test` | Resolves to Mac 2 IP address |
| **4** | Open service over HTTPS | `curl --cacert certs/ca.crt https://app.team1.test:8443/api/status` | Returns HTTP 200 OK without `-k` flag, valid trusted certificate |
| **5** | Show load balancing across backends | `./scripts/test_endpoints.sh` (Test 3) | `X-Backend: A` and `X-Backend: B` alternate across requests |
| **6** | Show Wireshark packet evidence | Open Wireshark, filter `tls` or `dns` | Show DNS query, TCP 3-way handshake, TLS handshake, encrypted HTTP data |
| **7** | Show HTTP headers and caching | `curl -i -H "If-None-Match: <etag>" https://app.team1.test:8443/cached` | Returns `HTTP/1.1 304 Not Modified` and `Cache-Control: max-age=60` |
| **8** | Fail one backend & prove continuity | Stop Backend A (`pkill -f backend_a.py`), then curl | Requests continue to succeed through Backend B (`X-Backend: B`) |
| **9** | Run Section 6.3 Failure Scenarios | `./scripts/run_failure_tests.sh` | Demonstrates all 5 failure scenarios with clear explanations |

---

## 4. Mac 2 Viva & Concept Defense Guide

### Q1: What is the primary role of Mac 2 in this project?
**Answer**: Mac 2 acts as the **Edge Reverse Proxy and Load Balancer**. It is the single public entry point for all client traffic. It handles **TLS Termination**, terminates HTTPS connections, and proxies requests downstream to Backend A (Mac 3) and Backend B (Mac 4) using **Round-Robin Load Balancing**.

### Q2: Why is TLS termination performed at the edge (Mac 2) instead of the backends?
**Answer**: Offloading TLS encryption and decryption to the edge proxy reduces computational overhead on backend application servers, centralizes certificate management (only one server needs the SSL certificate), and allows internal traffic between proxy and backends to run over high-speed local network sockets.

### Q3: How does Nginx perform load balancing and track backends?
**Answer**: Nginx uses an `upstream` cluster definition. By default, it uses a **Round-Robin** algorithm to distribute incoming client requests evenly across upstream servers (`127.0.0.1:3001` and `127.0.0.1:3002`). The `X-Backend` header set by each backend (`A` or `B`) is passed back to the client to prove which backend handled the request.

### Q4: How does HTTP Caching work with `Cache-Control` and `ETag` (304 Not Modified)?
**Answer**: 
- `Cache-Control: max-age=60` tells the browser/client that the response remains fresh for 60 seconds.
- `ETag` is a unique fingerprint (MD5 hash) of the resource content.
- On subsequent requests, the client sends `If-None-Match: "<etag>"`. If the content hasn't changed, the server responds with `HTTP 304 Not Modified` (without a body), saving bandwidth and reducing load.
