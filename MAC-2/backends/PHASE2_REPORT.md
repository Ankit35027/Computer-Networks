# Computer Networks Course Project - Phase 2 Final Report
## Phase 2: Harden, Recover, and Troubleshoot
**Machine Role: Mac 2 (Edge Reverse Proxy & Load Balancer)**

---

## 1. Executive Summary & Architecture Changes

In Phase 2, the core Phase 1 local networking infrastructure built on **Mac 2 (Edge Proxy)** was extended to achieve **resilience, service isolation, automated failover, and fault diagnosability**. No architecture components were rebuilt from scratch; instead, production-grade hardening mechanisms were added across DNS, firewall, reverse proxy, and diagnostic layers.

---

## 2. Resilience Tests & Extension Results

### Extension A: Backup DNS Resolver
- **Implementation**: Configured a secondary DNS server (`dnsmasq_backup.conf`) on Mac 3 with identical domain mapping records for `app.team1.test`. Client Macs were configured with primary (`10.7.8.10`) and secondary (`10.7.8.30`) DNS IP entries.
- **Resilience Test Result**: Stopping `dnsmasq` on Mac 1 resulted in seamless DNS query failover to Mac 3 without client request interruption.
- **Learning Summary**: DNS resolvers implement client-side fallback mechanisms. A DNS server failure halts name-to-IP resolution, whereas an application server failure allows resolution to succeed but results in HTTP 502/connection refusal.

### Extension B: DNS TTL and Controlled Record Change
- **Implementation**: Set `local-ttl=30` (30 seconds) on project DNS records and performed controlled IP cutovers.
- **Resilience Test Result**: Clients retained the cached IP for 30 seconds before issuing a fresh DNS query. Flushing local macOS DNS caches (`dscacheutil -flushcache`) instantly updated resolution.
- **Learning Summary**: Low TTL values enable rapid traffic migration during maintenance or emergency cutovers at the cost of increased DNS server query traffic, whereas long TTLs reduce DNS server load but delay failure recovery.

### Extension C: Service Isolation (Backend Firewall Rules)
- **Implementation**: Implemented macOS Packet Filter (`pf`) firewall rules in `configs/pf_backend_isolation.conf` to block direct external TCP traffic to backend ports `3001` and `3002`, restricting ingress access exclusively to Mac 2 (`10.7.8.201`).
- **Resilience Test Result**: Clients attempting direct connection to `http://<Mac3_IP>:3001` timed out or were refused, while requests routed through Mac 2 (`https://app.team1.test:8443`) succeeded.
- **Learning Summary**: Service isolation enforces the principle of least privilege in network architecture, preventing clients from bypassing edge security controls, WAF policies, or TLS termination.

### Extension D: High-Availability Failover Behavior
- **Implementation**: Configured Nginx passive health checking (`max_fails=1 fail_timeout=3s`) and automated upstream retries (`proxy_next_upstream error timeout http_502`).
- **Resilience Test Result**: When Backend A (`backend_a.py`) was abruptly terminated, Nginx immediately re-routed incoming client requests to Backend B (`backend_b.py`) with zero visible HTTP errors to the client. Upon restarting Backend A, round-robin load distribution resumed automatically.
- **Learning Summary**: Reverse proxies with upstream passive health checks provide transparent application-layer failover. However, the edge proxy itself remains a single point of failure (SPOF) unless paired with VRRP/Keepalived or floating IP clusters.

### Extension E: Controlled Edge Migration (DNS-Based Cutover)
- **Implementation**: Deployed a standby Nginx edge proxy on Mac 3 and updated DNS records to point `app.team1.test` to the standby IP.
- **Resilience Test Result**: Observed gradual client cutover governed by DNS TTL, proving edge replacement can occur without physical hardware changes or downtime.
- **Learning Summary**: DNS-based edge migration allows zero-downtime infrastructure upgrades and blue-green deployments by shifting traffic at the authoritative DNS layer.

### Extension F: Faculty-Injected Troubleshooting Challenge
- **Implementation**: Built [`scripts/troubleshoot_fault.sh`](file:///Users/kchhillar13/computer%20network/scripts/troubleshoot_fault.sh) for systematic top-down & bottom-up fault diagnosis.
- **Diagnostic Methodology**:
  1. **DNS Layer**: Verify name resolution via `dig app.team1.test`.
  2. **TCP Layer**: Verify socket connectivity via `nc -zv <IP> <Port>`.
  3. **TLS Layer**: Validate certificate trust & SNI via `openssl s_client`.
  4. **Application Layer**: Inspect HTTP status codes (200 vs 502 Bad Gateway) and `X-Backend` headers.
- **Learning Summary**: Systematic OSI layer isolation eliminates guesswork during outage troubleshooting. Isolating the fault layer first (DNS vs TCP vs TLS vs App) drastically reduces Mean Time to Resolution (MTTR).

---

## 3. Summary of Deliverables & Verification Suite

All Phase 1 & Phase 2 verification scripts, configuration files, certificates, and reports are ready for presentation in `/Users/kchhillar13/computer network/`.
