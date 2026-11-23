# Computer Networks Course Project — Phase 2 Final Report
## Phase 2: Harden, Recover, and Troubleshoot
**Project Title**: Private Network Service Platform — Resilience, Isolation & Failover  
**Team**: Team 1  
**Target Domain**: `app.team1.test` | `api.team1.test` | `team1.test`  
**Network Subnet**: `10.7.0.0/19` (Netmask: `255.255.224.0`, Gateway: `10.7.0.1`)  

---

## 1. Executive Summary & Architecture Evolution

In **Phase 1 (Build & Observe)**, the team established a fully operational private local service platform across four physical macOS machines, proving private DNS resolution, TLS 1.3 termination, round-robin load balancing across two independent backends, HTTP/2 multiplexing, and HTTP conditional caching (ETag / 304 Not Modified).

In **Phase 2 (Harden, Recover, and Troubleshoot)**, the system was hardened against single-point-of-failure risks, unauthorized network access, and unexpected service crashes. Rather than rebuilding the platform from scratch, production-grade resilience mechanisms were implemented across multiple protocol layers:
1. **DNS Layer**: Multi-resolver redundancy and TTL-governed traffic migration (Extensions A & B).
2. **Network / Security Layer**: Ingress service isolation using macOS Packet Filter (`pf`) rules (Extension C).
3. **Application / Transport Layer**: Upstream passive health monitoring, transparent HTTP retry, and standby edge migration (Extensions D & E).
4. **Diagnostic Layer**: Systematic OSI layer-by-layer troubleshooting framework for faculty-injected fault isolation (Extension F).

---

## 2. Machine Roles & Infrastructure Inventory

| Machine Folder | Hardware Role | LAN IPv4 | Bound Ports | Core Services Running | Resilience Extension |
|---|---|---|---|---|---|
| **`MAC-1/`** | Primary DNS Server & Client | `10.7.21.249` | `53/UDP`, `53/TCP` | `dnsmasq` v2.90, `dig`, `curl` | Primary DNS Lifecycle Control |
| **`MAC-2/`** | Edge Reverse Proxy & Load Balancer | `10.7.23.158` | `8443/TCP`, `80/TCP` | `nginx` v1.31.6 + TLS 1.3 | **Ext D**: Upstream Passive Health Monitoring |
| **`MAC-3/`** | Upstream Backend A, Backup DNS & Standby Edge | `10.7.22.2` | `3001/TCP`, `53/UDP`, `8443/TCP` | Node.js REST API (`server.js`), `dnsmasq`, `nginx` | **Ext A**: Backup DNS<br/>**Ext C**: PF Isolation<br/>**Ext E**: Standby Edge |
| **`MAC-4/`** | Upstream Backend B & Primary Client Node | `10.7.21.68` | `3002/TCP` | Node.js / Python REST API, Evaluation Client Suite | **Ext C**: PF Isolation<br/>Client Demonstration Controller |

---

## 3. Detailed Results of Phase 2 Extensions

### 3.1 Extension A: Backup DNS Resolver
- **Implementation**:
  - A secondary `dnsmasq` instance was configured and deployed on Mac 3 (`10.7.22.2`) with authoritative records identical to Mac 1 (`app.team1.test -> 10.7.23.158`).
  - Client Mac 4's macOS network resolver was configured with both nameservers using `networksetup`:
    ```bash
    sudo networksetup -setdnsservers Wi-Fi 10.7.21.249 10.7.22.2
    ```
- **Resilience Test & Verification**:
  1. Sent baseline query: Resolved via Primary DNS (`10.7.21.249`).
  2. Terminated `dnsmasq` on Mac 1 (`sudo pkill dnsmasq`).
  3. Re-sent query from client: The client resolver automatically fell back to the secondary DNS on Mac 3 (`10.7.22.2`), returning `10.7.23.158` with zero failure.
- **Viva Key Insight**:
  - *DNS Service Failure vs Application Server Failure*: A DNS failure halts name-to-IP resolution before any TCP handshake can begin (client sees `SERVFAIL` or `NXDOMAIN`). An application server failure occurs after successful DNS resolution and TLS establishment, producing an HTTP status code (`502 Bad Gateway` or `504 Gateway Timeout`).

---

### 3.2 Extension B: DNS TTL and Controlled Record Change
- **Implementation**:
  - Configured a short, visible TTL of 30 seconds (`local-ttl=30`) in `dnsmasq.conf`.
  - Simulating controlled IP cutover by changing the A record of `app.team1.test` to point to `10.7.22.2` (Standby Edge).
- **Resilience Test & Verification**:
  1. Client queried `app.team1.test`: DNS response returned `TTL: 30`.
  2. Updated record on DNS server and executed `kill -HUP $(pgrep dnsmasq)`.
  3. Client immediately queried again: Operating system returned the cached IP address for the duration of the remaining TTL window.
  4. Executed manual cache flush:
     ```bash
     sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
     ```
  5. Subsequent query immediately returned the new IP address.
- **Viva Key Insight**:
  - *TTL Engineering Trade-offs*: Low TTL (30s) enables rapid cutover during outages or blue-green deployments at the cost of higher query volume to authoritative nameservers. High TTL (e.g. 86400s) minimizes DNS server load and lookup latency, but introduces caching inertia that delays emergency traffic rerouting.

---

### 3.3 Extension C: Service Isolation (Backend Firewall Rules)
- **Implementation**:
  - Configured macOS Packet Filter (`pfctl`) rules on Mac 3 (`configs/pf_backend_isolation.conf`) and Mac 4 to restrict direct incoming TCP connections to backend ports `3001` and `3002`.
  - Rules explicitly allow traffic originating from Mac 2 Edge Proxy (`10.7.23.158`) while dropping or resetting direct requests from any other LAN host:
    ```pf
    ext_if = "en0"
    edge_proxy = "10.7.23.158"
    backend_port = "3001"
    pass in quick on $ext_if proto tcp from $edge_proxy to any port $backend_port
    block in quick on $ext_if proto tcp from any to any port $backend_port
    ```
- **Resilience Test & Verification**:
  - *Direct Client Access*: Client Mac 4 executed `curl http://10.7.22.2:3001/api/status` → **Connection Refused / Timed Out**.
  - *Edge-Routed Access*: Client Mac 4 executed `curl https://app.team1.test:8443/api/status` → **200 OK** (Proxy routed request successfully).
- **Viva Key Insight**:
  - *Defense-in-Depth & Least Privilege*: Direct exposure of backend ports exposes unencrypted HTTP traffic, circumvents edge authentication, and bypasses reverse proxy rate-limiting. Service isolation ensures all ingress traffic is forced through TLS inspection and Edge proxy controls.

---

### 3.4 Extension D: High-Availability Failover Behavior
- **Implementation**:
  - Enhanced Nginx upstream load-balancing pool with passive health check directives and automated next-upstream retries:
    ```nginx
    upstream backend_cluster {
        server 10.7.22.2:3001 max_fails=1 fail_timeout=3s;
        server 10.7.21.68:3002 max_fails=1 fail_timeout=3s;
    }
    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
    proxy_next_upstream_tries 2;
    proxy_next_upstream_timeout 3s;
    ```
- **Resilience Test & Verification**:
  1. Continuous traffic stream sent to `https://app.team1.test:8443/api/status`: Verified alternation between `X-Backend: A` and `X-Backend: B`.
  2. Terminated Backend A on Mac 3 (`pkill -f "node server.js"`).
  3. Client stream showed 100% successful responses (`HTTP 200 OK`) serviced entirely by Backend B (`X-Backend: B`) with zero dropped requests.
  4. Restarted Backend A on Mac 3: Nginx restored Backend A to the active rotation automatically within 3 seconds.
- **Viva Key Insight**:
  - *Single Point of Failure (SPOF) Analysis*: While backend applications have full failover redundancy, the Edge Proxy on Mac 2 remains an architectural SPOF. In production, this is eliminated using Virtual IP (VIP) clustering with VRRP (`keepalived`), BGP Anycast routing, or DNS Round-Robin with automated health checking.

---

### 3.5 Extension E: Controlled Edge Migration (DNS-Based Cutover)
- **Implementation**:
  - Pre-configured standby Nginx edge proxy on Mac 3 listening on port `8443` with identical SAN TLS certificates.
  - Performed DNS cutover by changing authoritative A record: `app.team1.test` → `10.7.22.2`.
- **Resilience Test & Verification**:
  - Verified traffic shift from Mac 2 to Mac 3 without changing client application code or hardware connections.
- **Viva Key Insight**:
  - Mirrors production blue/green routing and data center evacuation procedures.

---

### 3.6 Extension F: Faculty-Injected Troubleshooting Challenge
- **Implementation**:
  - Developed automated diagnostic script [`MAC-2/scripts/troubleshoot_fault.sh`](file:///Users/kchhillar13/me/Computer-Networks/MAC-2/scripts/troubleshoot_fault.sh) implementing a disciplined top-down / bottom-up OSI diagnostic flow.
- **Diagnostic Decision Matrix**:

| Layer | Inspection Tool | Expected Healthy Output | Symptom of Injected Fault | Root Cause & Resolution |
|---|---|---|---|---|
| **Layer 3 (IP)** | `ping -c 2 10.7.23.158` | 0% packet loss | Host Unreachable / 100% loss | Wi-Fi disconnected or wrong IP subnet |
| **Layer 7 (DNS)** | `dig +short app.team1.test` | Returns `10.7.23.158` | Empty / `connection timed out` | dnsmasq stopped or client pointing to wrong DNS |
| **Layer 4 (TCP)** | `nc -zv 10.7.23.158 8443` | Connection to port 8443 succeeded | Connection refused / timed out | Nginx stopped or port blocked by firewall |
| **Layer 6 (TLS)** | `openssl s_client -connect ...` | `Verify return code: 0 (ok)` | Certificate expired / untrusted CA | Missing CA in keychain or expired cert |
| **Layer 7 (App)** | `curl -i https://app.team1.test:8443` | `HTTP/2 200 OK` | `HTTP/2 502 Bad Gateway` | Both backends (3001 & 3002) are stopped |

---

## 4. Phase 2 Demonstration Checklist (Review 2 Sequence)

| Step # | Evaluation Demonstration | Target Machine | Verified Execution Command |
|---|---|---|---|
| **1** | Multi-Machine Topology & Roles | All | Display `ARCHITECTURE.md` |
| **2** | LAN Ping Reachability | Mac 4 | `./network/ping_team.sh` |
| **3** | Primary & Backup DNS Resolution | Mac 4 | `./client/test_phase2_backup_dns.sh` |
| **4** | HTTPS Service over Private Domain | Mac 4 | `curl https://app.team1.test:8443/api/status` |
| **5** | Dynamic Round-Robin Alternation | Mac 4 | `./client/test_load_balancing.sh` |
| **6** | Wireshark Protocol Proof (DNS/TCP/TLS) | Mac 2 / Mac 4 | Wireshark capture inspection |
| **7** | HTTP Caching & 304 Validation | Mac 4 | `./client/test_caching.sh` |
| **8** | Single Backend Failure Recovery | Mac 2 / Mac 4 | `./client/test_phase2_ha_failover.sh` |
| **9** | Primary DNS Failure & Backup Failover | Mac 1 / Mac 4 | Stop Mac 1 DNS; verify resolution via Mac 3 |
| **10**| Service Isolation (Firewall Protection) | Mac 3 / Mac 4 | `./client/test_phase2_firewall_isolation.sh` |
| **11**| Faculty Fault Diagnosis & Viva | All | Execute `troubleshoot_fault.sh` & answer viva questions |

---

## 5. Conclusion

Phase 2 successfully transformed the baseline Phase 1 networking prototype into a resilient, isolated, and fault-tolerant private platform. All deliverables, automation scripts, evidence artifacts, and viva resources are verified and ready for evaluation.
