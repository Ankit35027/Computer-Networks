> **Note (24 Nov 2026):** this guide was written before Phase 2 testing and may show old IPs (`10.7.21.249`, `10.7.23.158`, `10.7.22.2`, `10.7.21.68`) or placeholders (`10.7.8.x`). Current IPs: [`team.env`](../../team.env). Current setup and results: [`CONFIGURATION_BUNDLE.md`](../../docs/CONFIGURATION_BUNDLE.md) and [`PHASE2_REPORT.md`](../../docs/PHASE2_REPORT.md).

# Mac 4: Phase 2 Client & Backend B Demonstration Guide
## Harden, Recover, and Troubleshoot

**Machine Role**: 
1. Upstream REST Backend B (Port 3002)
2. Service Isolation Firewall Node (`pfctl` for Port 3002)
3. Primary Evaluation Client Node for Demonstration Steps

**Assigned LAN IP**: `10.7.21.68`  
**Teammate Roles & IPs**:
- Mac 1 (Primary DNS): `10.7.21.249`
- Mac 2 (Edge Reverse Proxy & LB): `10.7.23.158`
- Mac 3 (Backend A / Backup DNS / Standby Edge): `10.7.22.2`

---

## 🚀 Step 1: Start Backend Server B
Start your backend server listening on port 3002:
```bash
./backend/start_backend.sh
```
Verify local response:
```bash
curl http://127.0.0.1:3002/api/status
```
Expected response:
```json
{"status":"ok","backend":"B","server_port":3002}
```

---

## 🔒 Step 2: Apply Service Isolation Firewall on Mac 4 (Extension C)
Apply macOS Packet Filter (`pf`) rules so only Mac 2 Edge Proxy (`10.7.23.158`) can connect to port 3002:
```bash
sudo pfctl -e -f configs/pf_backend_isolation.conf
```
To verify active rules:
```bash
sudo pfctl -s rules
```
To disable after demonstration:
```bash
sudo pfctl -d
```

---

## 🌐 Step 3: Configure Multi-Resolver DNS on Mac 4 (Extension A)
Configure macOS network settings to use Mac 1 as Primary DNS and Mac 3 as Secondary DNS:
```bash
./client/setup_phase2_dns.sh
```

---

## 🎯 Step 4: Run Phase 2 Demonstration Suite
You can run the entire automated Phase 2 demonstration suite interactively:
```bash
./client/run_phase2_evaluation.sh
```

Or execute individual test scripts per extension:

### Extension A: Backup DNS Failover Demonstration
```bash
./client/test_phase2_backup_dns.sh
```
- **What happens**: Mac 1 primary DNS stops. Client sends query; query automatically succeeds through Mac 3 backup DNS!

### Extension B: DNS TTL & Cache Invalidation
```bash
./client/test_phase2_ttl_cutover.sh
```
- **What happens**: Shows TTL (30s) in DNS answer section, sends queries showing cached resolution, and flushes cache manually via `dscacheutil -flushcache` and `killall -HUP mDNSResponder`.

### Extension C: Service Isolation Verification
```bash
./client/test_phase2_firewall_isolation.sh
```
- **What happens**: Shows that direct curl to Mac 3 (`http://10.7.22.2:3001/api/status`) times out or is connection-refused, while accessing `https://app.team1.test:8443/api/status` through Mac 2 succeeds!

### Extension D: High-Availability Failover & Recovery
```bash
./client/test_phase2_ha_failover.sh 10
```
- **What happens**: 
  1. While both backends are running: alternating responses between `X-Backend: A` and `X-Backend: B`.
  2. When Mac 3 stops Backend A: 100% of requests are routed to Backend B with zero dropped requests.
  3. When Mac 3 restarts Backend A: alternating load distribution resumes automatically.

### Extension E: Controlled Edge Migration (Standby Cutover)
```bash
./client/test_phase2_edge_migration.sh
```
- **What happens**: Inspects resolved Edge IP and verifies whether client is hitting Primary Edge (Mac 2: `10.7.23.158`) or Standby Edge (Mac 3: `10.7.22.2`).
