# Mac 2: Edge Reverse Proxy & Load Balancer Guide

**Machine Role**: Edge Gateway, TLS Termination Server, HTTP/2 Proxy, and Load Balancer  
**Local IP**: `10.7.8.201`  
**Domain**: `app.team1.test` | `api.team1.test`  

---

## 1. Quick Start & Local Environment
Ensure Nginx and Python dependencies are active:
```bash
# Start Python Backends (Ports 3001 & 3002)
./scripts/start_backends.sh start

# Start Nginx Edge Proxy (HTTPS Port 8443)
./scripts/start_nginx.sh start
```

---

## 2. Certificate Trust & Domain Setup
Run the following commands on Mac 2 to map domains locally and trust the custom Root CA certificate:
```bash
echo "127.0.0.1 app.team1.test api.team1.test team1.test" | sudo tee -a /etc/hosts
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/ca.crt
```

---

## 3. Multi-Mac LAN Upstream Configuration
When Mac 3 and Mac 4 are active on the physical LAN, update `configs/nginx.conf` (Upstream Pool lines 40–45) to point to their IPs:
```nginx
upstream backend_cluster {
    server <Mac3_IP>:3001 max_fails=1 fail_timeout=3s;
    server <Mac4_IP>:3002 max_fails=1 fail_timeout=3s;
}
```
After editing `configs/nginx.conf`, reload Nginx:
```bash
./scripts/start_nginx.sh reload
```

---

## 4. Verification & Failure Test Suites
Execute the automated verification scripts:
```bash
# 1. Full Phase 1 Endpoint Test Suite
./scripts/test_endpoints.sh

# 2. Section 6.3 Mandatory Failure Demonstrations
./scripts/run_failure_tests.sh
```

---

## 5. Wireshark Evidence Export (`.pcapng`)
Open Wireshark on Mac 2, filter by protocol, perform requests, and export captures to `evidence/`:
- `evidence/dns_query.pcapng` (Filter: `dns`)
- `evidence/tcp_3way_handshake.pcapng` (Filter: `tcp.flags.syn == 1`)
- `evidence/tls_handshake.pcapng` (Filter: `tls`)

---

## 6. Faculty Fault Injection Diagnostic (Extension F)
If the faculty injects a fault into the running system, run top-down layer diagnosis:
```bash
./scripts/troubleshoot_fault.sh
```
