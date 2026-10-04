# Computer Networks Course Project - Machine-by-Machine Pending Tasks Checklist

**Project Title**: Edge Reverse Proxy, Load Balancer & High-Availability Infrastructure  
**Target Domain**: `app.team1.test` | `api.team1.test` | `team1.test`  
**Current Date**: October 2026  

---

## 🖥️ Mac 1: Primary DNS Server

> **Role**: Primary Authoritative & Recursive DNS Resolver for Team 1.

### 📋 Setup & Deployment Checklist
- [ ] **Install `dnsmasq`**:
  ```bash
  brew install dnsmasq
  ```
- [ ] **Copy Configuration**:
  Copy `configs/dnsmasq_primary.conf` from Mac 2 to Mac 1 at `/opt/homebrew/etc/dnsmasq.conf` or `/etc/dnsmasq.conf`.
- [ ] **Configure Static LAN IP**:
  Assign static IPv4 address (e.g., `10.7.8.10`) on network interface `en0`.
- [ ] **Verify Domain Mapping Rules**:
  Ensure the following records exist in `dnsmasq_primary.conf`:
  ```conf
  address=/app.team1.test/10.7.8.201
  address=/api.team1.test/10.7.8.201
  address=/team1.test/10.7.8.201
  local-ttl=30
  ```
- [ ] **Start Service**:
  ```bash
  sudo brew services start dnsmasq
  # Or run directly:
  sudo dnsmasq -C configs/dnsmasq_primary.conf -d
  ```
- [ ] **Verification Command**:
  ```bash
  dig @127.0.0.1 app.team1.test
  ```

---

## 🖥️ Mac 2: Edge Reverse Proxy & Load Balancer (Your Machine)

> **Role**: TLS Termination Gateway, HTTP/2 Server, Upstream Load Balancer, and Health Monitor.

### 📋 Setup & Deployment Checklist
- [x] **Install Nginx**: Completed via Homebrew (`brew install nginx`).
- [x] **Generate Root CA & SAN SSL Certs**: Generated in `certs/` for `*.team1.test`.
- [x] **Nginx Configured & Tested**: Configured in `configs/nginx.conf` with HTTPS port `8443`, HTTP/2, ETag caching, and passive health checks.
- [ ] **Add Local Domain Mapping & Trust CA**:
  Run in terminal:
  ```bash
  echo "127.0.0.1 app.team1.test api.team1.test team1.test" | sudo tee -a /etc/hosts
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/ca.crt
  ```
- [ ] **Update Upstream Cluster IPs (When Multi-Mac LAN Active)**:
  When Mac 3 and Mac 4 are connected on LAN, edit `configs/nginx.conf` lines 42–43:
  ```nginx
  upstream backend_cluster {
      server <Mac3_IP>:3001 max_fails=1 fail_timeout=3s;
      server <Mac4_IP>:3002 max_fails=1 fail_timeout=3s;
  }
  ```
- [ ] **Save Wireshark Capture Evidence Files (`.pcapng`)**:
  Open Wireshark on Mac 2 during test runs and save captures to `evidence/`:
  - `dns_query.pcapng` (filter: `dns`)
  - `tcp_3way_handshake.pcapng` (filter: `tcp.flags.syn == 1`)
  - `tls_handshake.pcapng` (filter: `tls`)
- [ ] **Run Pre-Demo Verification**:
  ```bash
  ./scripts/test_endpoints.sh
  ./scripts/run_failure_tests.sh
  ```

---

## 🖥️ Mac 3: Secondary DNS Backup, Upstream Backend A & Standby Edge

> **Role**: Backup DNS Server (Extension A), Upstream Application Server A (Port 3001), Service Isolation Node (Extension C), and Standby Edge Proxy (Extension E).

### 📋 Setup & Deployment Checklist
- [ ] **Install `dnsmasq` & Python 3**:
  ```bash
  brew install dnsmasq python3
  ```
- [ ] **Deploy Backup DNS Resolver (Extension A)**:
  Copy `configs/dnsmasq_backup.conf` to Mac 3 and start `dnsmasq`:
  ```bash
  sudo dnsmasq -C configs/dnsmasq_backup.conf -d
  ```
- [ ] **Deploy REST Application Server A**:
  Copy `backends/backend_a.py` and helper `scripts/start_backends.sh` to Mac 3. Start Backend A:
  ```bash
  python3 backends/backend_a.py --port 3001
  ```
- [ ] **Apply Service Isolation Firewall Rules (Extension C)**:
  Apply Packet Filter (`pf`) rules on Mac 3 to block direct external traffic to port 3001 except from Mac 2 (`10.7.8.201`):
  ```bash
  sudo pfctl -e -f configs/pf_backend_isolation.conf
  ```
- [ ] **Configure Standby Edge Proxy (Extension E)**:
  Install Nginx on Mac 3 with identical `nginx.conf` to prepare for DNS cutover demonstration.
- [ ] **Trust Root CA Certificate**:
  ```bash
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/ca.crt
  ```

---

## 🖥️ Mac 4: Upstream Backend B & Client Evaluation Node

> **Role**: Upstream Application Server B (Port 3002) and Primary Evaluation Client Node.

### 📋 Setup & Deployment Checklist
- [ ] **Install Python 3 & `curl`**:
  Ensure standard Python 3 runtime is available.
- [ ] **Deploy REST Application Server B**:
  Copy `backends/backend_b.py` to Mac 4. Start Backend B:
  ```bash
  python3 backends/backend_b.py --port 3002
  ```
- [ ] **Configure Client DNS Resolver Order**:
  In macOS Network Settings (or `/etc/resolv.conf`), set:
  - **Primary DNS**: `<Mac1_IP>` (e.g. `10.7.8.10`)
  - **Secondary DNS**: `<Mac3_IP>` (e.g. `10.7.8.30`)
- [ ] **Trust Root CA Certificate**:
  ```bash
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/ca.crt
  ```
- [ ] **Verify End-to-End Client Connectivity**:
  Execute test commands from Mac 4 towards Mac 2 Edge Proxy:
  ```bash
  dig app.team1.test
  curl https://app.team1.test:8443/api/status
  ```

---

## 🎯 Final Demonstration Checklist (Section 8 Sequence)

| Step # | Evaluator Expectation | Target Machine | Execution Command |
|---|---|---|---|
| **1** | Topology & IP Map | All | Display `ARCHITECTURE.md` |
| **2** | LAN Ping Connectivity | Mac 4 | `ping <Mac1_IP>`, `ping <Mac2_IP>`, `ping <Mac3_IP>` |
| **3** | Private DNS Lookup | Mac 4 | `dig app.team1.test` (resolves to Mac 2 IP) |
| **4** | HTTPS Connection (No Warning) | Mac 4 | `curl https://app.team1.test:8443/api/status` |
| **5** | Load Balancing Alternation | Mac 4 | Run 10x curl requests, observe `X-Backend: A` / `B` |
| **6** | Wireshark Protocol Flow | Mac 2 | Open `.pcapng` files in Wireshark (DNS, TCP 3-way, TLS SNI) |
| **7** | HTTP Caching & 304 | Mac 4 | `curl -i -H "If-None-Match: <etag>" https://app.team1.test:8443/cached` |
| **8** | Fail Backend A | Mac 3 / Mac 2 | Kill `backend_a.py` on Mac 3; verify traffic routes to Backend B |
| **9** | Phase 2 Extensions (DNS / HA) | Mac 1 & 3 | Stop Mac 1 DNS; verify fallback to Mac 3 backup DNS |
| **10**| Faculty Fault Diagnosis | Mac 2 | Run `./scripts/troubleshoot_fault.sh` layer-by-layer |
| **11**| Individual Viva Q&A | All | Answer theoretical questions on OSI, TLS, DNS, HA |
