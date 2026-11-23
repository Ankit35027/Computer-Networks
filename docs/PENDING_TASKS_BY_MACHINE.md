# Computer Networks Course Project — Team Task & Review 2 Execution Checklist
## Private Network Service Platform — Phase 2: Harden, Recover, and Troubleshoot

**Project Title**: Edge Reverse Proxy, Load Balancer & High-Availability Infrastructure  
**Target Domain**: `app.team1.test` | `api.team1.test` | `team1.test`  
**Subnet Range**: `10.7.0.0/19` (Netmask: `255.255.224.0`, Gateway: `10.7.0.1`)  

---

## 🖥️ Live Team IP & Hardware Role Matrix

| Machine Directory | Hardware Role | Assigned LAN IPv4 | Bound Ports | Primary Services |
|---|---|---|---|---|
| **[`MAC-1/`](../MAC-1/)** | Primary DNS Server & Client | `10.7.21.249` | `53/UDP`, `53/TCP` | `dnsmasq` Primary DNS Resolver (TTL: 30s) |
| **[`MAC-2/`](../MAC-2/)** | Edge Proxy & Load Balancer | `10.7.23.158` | `8443/TCP`, `80/TCP` | `nginx` + TLS 1.3 Reverse Proxy & HA Passive Health Monitor |
| **[`MAC-3/`](../MAC-3/)** | Backend A, Backup DNS & Standby Edge | `10.7.22.2` | `3001/TCP`, `53/UDP`, `8443/TCP` | Node.js REST API (`server.js`), Backup `dnsmasq`, Standby `nginx` |
| **[`MAC-4/`](../MAC-4/)** | Backend B & Client Node | `10.7.21.68` | `3002/TCP` | Node.js / Python REST API, Automated Client Evaluation Suite |

---

## 🖥️ Mac 1: Primary DNS Server Checklist

> **Role**: Primary Authoritative & Recursive DNS Resolver for Team 1.

### 📋 Setup & Phase 2 Actions
- [x] **Deploy `dnsmasq.conf`**: Configured with `local-ttl=30` and mapping `app.team1.test -> 10.7.23.158`.
- [x] **Primary Service Starter**:
  ```bash
  cd MAC-1
  sudo ./scripts/phase2_dns_failover_demo.sh start
  ```
- [x] **Phase 2 Extension A Demo (Primary DNS Outage Simulation)**:
  ```bash
  sudo ./scripts/phase2_dns_failover_demo.sh stop
  # Verify client resolves via Mac 3 backup DNS!
  # Restart when done:
  sudo ./scripts/phase2_dns_failover_demo.sh start
  ```
- [x] **Phase 2 Extension B & E Demo (Record Cutover Simulation)**:
  ```bash
  # Change DNS to point to Standby Edge (Mac 3):
  sudo ./scripts/phase2_ttl_cutover_demo.sh cutover-standby
  # Restore to Primary Edge (Mac 2):
  sudo ./scripts/phase2_ttl_cutover_demo.sh restore-primary
  ```

---

## 🖥️ Mac 2: Edge Reverse Proxy & Load Balancer Checklist

> **Role**: TLS Termination Gateway, HTTP/2 Server, Upstream Load Balancer, and Health Monitor.

### 📋 Setup & Phase 2 Actions
- [x] **Install Nginx & Certificates**: Local Root CA (`ca.crt`) and SAN SSL certificate (`server.crt`).
- [x] **Start Nginx with Upstream Pool & Passive Health Checks (Extension D)**:
  ```bash
  cd MAC-2
  ./scripts/start_nginx.sh start
  ```
- [x] **Run Phase 2 Extensions Master Demonstration**:
  ```bash
  ./scripts/run_phase2_extensions.sh
  ```
- [x] **Extension F Faculty Fault Troubleshooting**:
  ```bash
  ./scripts/troubleshoot_fault.sh
  ```

---

## 🖥️ Mac 3: Backend A, Backup DNS & Standby Edge Checklist

> **Role**: Upstream REST API (Port 3001), Backup DNS Resolver (Ext A), Service Isolation Firewall (Ext C), Standby Edge Proxy (Ext E).

### 📋 Setup & Phase 2 Actions
- [x] **Launch All Services via Master Script**:
  ```bash
  cd MAC-3
  sudo ./start-all.sh
  ```
- [x] **Verify Individual Components**:
  ```bash
  # 1. Start Backend A
  node server.js
  # 2. Start Backup DNS (Extension A)
  sudo dnsmasq -C configs/dnsmasq_backup.conf -d
  # 3. Apply PF Firewall Service Isolation (Extension C)
  sudo pfctl -e -f configs/pf_backend_isolation.conf
  # 4. Start Standby Edge (Extension E)
  sudo nginx -c $(pwd)/configs/nginx.conf
  ```
- [x] **Run Local Phase 2 Verification**:
  ```bash
  ./scripts/test_mac3_phase2.sh
  ```
- [x] **Firewall Rollback After Evaluation**:
  ```bash
  sudo pfctl -d
  ```

---

## 🖥️ Mac 4: Backend B & Client Evaluation Node Checklist

> **Role**: Upstream REST API (Port 3002) and Primary Client Demonstration Runner.

### 📋 Setup & Phase 2 Actions
- [x] **Start Backend Server B**:
  ```bash
  cd MAC-4
  ./backend/start_backend.sh
  ```
- [x] **Apply Service Isolation Firewall (Extension C)**:
  ```bash
  sudo pfctl -e -f configs/pf_backend_isolation.conf
  ```
- [x] **Configure Multi-Resolver DNS (Primary 10.7.21.249 + Backup 10.7.22.2)**:
  ```bash
  ./client/setup_phase2_dns.sh
  ```
- [x] **Run Complete Phase 2 Interactive Evaluation**:
  ```bash
  ./client/run_phase2_evaluation.sh
  ```
- [x] **Individual Extension Client Scripts**:
  - `Extension A (Backup DNS)`: `./client/test_phase2_backup_dns.sh`
  - `Extension B (DNS TTL & Cache Invalidation)`: `./client/test_phase2_ttl_cutover.sh`
  - `Extension C (Service Isolation Verification)`: `./client/test_phase2_firewall_isolation.sh`
  - `Extension D (HA Failover Stream)`: `./client/test_phase2_ha_failover.sh 10`
  - `Extension E (Edge Cutover Status)`: `./client/test_phase2_edge_migration.sh`

---

## 🎯 Review 2 Demonstration Sequence (11 Evaluation Steps)

| Step # | Evaluator Expectation | Target Machine | Execution Command |
|---|---|---|---|
| **1** | Topology & IP Map | All | Display `ARCHITECTURE.md` |
| **2** | LAN Ping Connectivity | Mac 4 | `./network/ping_team.sh` |
| **3** | Private DNS Lookup | Mac 4 | `dig app.team1.test` (resolves to `10.7.23.158`) |
| **4** | HTTPS Connection (No Warning) | Mac 4 | `curl https://app.team1.test:8443/api/status` |
| **5** | Load Balancing Alternation | Mac 4 | `./client/test_load_balancing.sh` (alternates A & B) |
| **6** | Wireshark Protocol Flow | Mac 2 / Mac 4 | Point out DNS query, TCP 3-way, TLS SNI in Wireshark |
| **7** | HTTP Caching & 304 | Mac 4 | `./client/test_caching.sh` |
| **8** | Fail Backend A & Recovery | Mac 3 / Mac 4 | Kill `server.js` on Mac 3; run `./client/test_phase2_ha_failover.sh` |
| **9** | Primary DNS Failure & Backup Resolver | Mac 1 / Mac 4 | Stop Mac 1 DNS; run `./client/test_phase2_backup_dns.sh` |
| **10**| Service Isolation (Firewall Protection)| Mac 3 / Mac 4 | Run `./client/test_phase2_firewall_isolation.sh` |
| **11**| Faculty Fault Diagnosis & Viva | All | Run `./scripts/troubleshoot_fault.sh` & answer viva questions |
