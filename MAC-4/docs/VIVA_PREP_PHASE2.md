# Phase 2 Individual Viva Preparation Guide
## Team 1 — Computer Networks Course Project

> **Essential Reference**: Every team member must understand these concepts thoroughly for the individual viva session in Review 2.

---

### Q1: What is the difference between a DNS service failure and an application server failure?
- **DNS Service Failure**:
  - The client cannot resolve the domain name (`app.team1.test`) to an IP address.
  - The failure occurs at the **Application/DNS layer (Port 53 UDP/TCP)** before any TCP connection to the web server can even begin.
  - Diagnostic tools (`dig`, `nslookup`) return `SERVFAIL`, `NXDOMAIN`, or timeout (`connection timed out; no servers could be reached`).
  - Browser shows `DNS_PROBE_FINISHED_NXDOMAIN`.
- **Application Server Failure**:
  - DNS resolution succeeds completely, returning the IP address of the edge proxy (`10.7.23.158`).
  - The client successfully completes TCP 3-way handshake and TLS handshake with the reverse proxy.
  - The failure occurs when the reverse proxy attempts to communicate with the upstream backend servers (ports 3001/3002).
  - The client receives an explicit HTTP response: `502 Bad Gateway` (if both backends are unreachable) or `504 Gateway Timeout`.

---

### Q2: What is DNS TTL? What are the trade-offs between low and high TTL values?
- **Definition**: TTL (Time to Live) is a 32-bit field in a DNS resource record that specifies the number of seconds the record may be cached by intermediate resolvers and client operating systems before being discarded.
- **Low TTL (e.g., 30 seconds)**:
  - *Advantages*: Enables rapid DNS record updates, fast failover, and quick blue-green traffic cutover. If an edge proxy fails, clients switch to the backup within seconds.
  - *Disadvantages*: Significantly higher query load on authoritative DNS servers; higher request latency because clients must query DNS more frequently rather than reading from cache.
- **High TTL (e.g., 86400 seconds / 24 hours)**:
  - *Advantages*: Drastically reduces DNS traffic and lookup latency due to high cache hit ratios.
  - *Disadvantages*: Slow propagation of IP changes. If an IP needs to change during an emergency outage, clients will continue hitting the dead server until the TTL expires (DNS caching inertia).

---

### Q3: Why is Service Isolation (Firewall Rules) important in a reverse proxy architecture?
- **Principle**: Enforces **Least Privilege** and **Defense-in-Depth**.
- **Security threat without isolation**:
  - If backend servers listen on `0.0.0.0:3001` without firewall rules, any device on the LAN can bypass the Edge Proxy and connect directly to the backend over unencrypted plain HTTP.
  - This bypasses:
    1. TLS encryption (traffic is eavesdropped on LAN)
    2. Rate limiting, WAF (Web Application Firewall) rules, and authentication at the Edge
    3. Caching and load balancing policies
- **PF Firewall Solution**:
  - `pfctl` rules block all incoming traffic to ports 3001 & 3002 from any IP **except** the Edge Proxy (`10.7.23.158`).
  - Clients attempting direct connections receive connection refused or timeout.

---

### Q4: How does Nginx perform Passive Health Checking and Failover (Extension D)?
- **Passive Health Checking**:
  - Nginx monitors live production client requests rather than sending artificial probe pings (which is Active Health Checking, a commercial Nginx Plus feature).
- **Configuration Directives**:
  - `max_fails=1`: Number of failed communication attempts within `fail_timeout` that causes Nginx to mark the upstream server as temporarily unavailable.
  - `fail_timeout=3s`: The duration the server is marked unavailable before Nginx tests it again with another request.
  - `proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;`: If the first selected backend returns an error, timeout, or 502, Nginx **immediately and transparently passes the same client request to the next upstream backend** in the pool.
- **User Experience**: The client experiences zero dropped requests and receives a 200 OK without noticing that a backend crashed.

---

### Q5: What is the Single Point of Failure (SPOF) in our current topology, and how can it be eliminated in production?
- **Current SPOF**: The **Edge Reverse Proxy (Mac 2 at 10.7.23.158)**. If Mac 2 crashes, the entire platform becomes unreachable even though both backends (Mac 3 and Mac 4) are healthy.
- **How to Eliminate SPOF in Production**:
  1. **Floating / Virtual IP (VIP) with VRRP (Keepalived / CARP)**:
     - Run two identical edge proxies (Primary Mac 2, Backup Mac 3) sharing a virtual IP address.
     - Keepalived heartbeats detect master failure and automatically migrate the VIP to the backup node within milliseconds without changing DNS.
  2. **DNS Round-Robin / DNS Health Failover**:
     - Publish multiple A records (`app.team1.test -> 10.7.23.158` and `10.7.22.2`).
     - Use a health-checking DNS service (e.g. AWS Route 53 health checks) to automatically remove an unhealthy edge proxy from DNS responses.
  3. **BGP Anycast Routing**:
     - Announce the same IP address from multiple edge nodes via BGP; routers automatically divert traffic to the closest available edge node.

---

### Q6: How does DNS-Based Edge Migration work (Extension E)?
- Standby Nginx edge proxy is pre-deployed on Mac 3 with identical SSL certificates and proxy routing configs.
- The authoritative DNS server updates the A record for `app.team1.test` from `10.7.23.158` to `10.7.22.2`.
- Existing clients whose DNS cache has not expired continue using Mac 2.
- As the 30-second TTL expires, clients re-resolve `app.team1.test` and migrate smoothly to Mac 3.
- This enables zero-downtime blue/green infrastructure migrations and maintenance.

---

### Q7: Explain the systematic Layer-by-Layer troubleshooting methodology (Extension F).
When the faculty injects a fault into the running system, follow a strict bottom-up / top-down OSI sequence:
1. **Layer 3 (Network / IP)**:
   - Command: `ping -c 2 <Target_IP>`
   - Verifies: Physical link, Wi-Fi association, ARP resolution, and IP routing.
2. **Layer 7 (DNS Resolution)**:
   - Command: `dig app.team1.test`
   - Verifies: Name resolution, correct authoritative resolver, valid A record mapping.
3. **Layer 4 (Transport / TCP)**:
   - Command: `nc -zv <Target_IP> 8443` or `nc -zv <Target_IP> 3001`
   - Verifies: Port reachability, process listening on port (`lsof -i :port`), and firewall (`pfctl`) rules.
4. **Layer 6 (Presentation / TLS Handshake)**:
   - Command: `openssl s_client -connect <IP>:8443 -servername app.team1.test -CAfile certs/ca.crt`
   - Verifies: TLS certificate validity, SNI match, trust chain, cipher negotiation.
5. **Layer 7 (Application / HTTP)**:
   - Command: `curl -v https://app.team1.test:8443/api/status`
   - Verifies: HTTP status codes (200 OK vs 502 Bad Gateway), response headers (`X-Backend: A/B`), and upstream proxy routing.
