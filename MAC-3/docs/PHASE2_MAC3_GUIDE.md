> **Note (24 Nov 2026):** this guide was written before Phase 2 testing and may show old IPs (`10.7.21.249`, `10.7.23.158`, `10.7.22.2`, `10.7.21.68`) or placeholders (`10.7.8.x`). Current IPs: [`team.env`](../../team.env). Current setup and results: [`CONFIGURATION_BUNDLE.md`](../../docs/CONFIGURATION_BUNDLE.md) and [`PHASE2_REPORT.md`](../../docs/PHASE2_REPORT.md).

# Mac 3: Phase 2 Operational & Evaluation Guide
## Harden, Recover, and Troubleshoot

**Machine Role**: 
1. Upstream REST Backend A (Port 3001)
2. Backup DNS Resolver (Extension A — Port 53)
3. Service Isolation Firewall Node (Extension C — `pfctl`)
4. Standby Edge Gateway (Extension E — Nginx Port 8443)

**Assigned LAN IP**: `10.7.22.2`  
**Teammate Roles & IPs**:
- Mac 1 (Primary DNS): `10.7.21.249`
- Mac 2 (Primary Edge Proxy & LB): `10.7.23.158`
- Mac 4 (Backend B & Client Node): `10.7.21.68`

---

## 🚀 Quick Execution: Starting Mac 3 Services

To start all Mac 3 services together for Phase 2:
```bash
sudo ./start-all.sh
```

Or start individual components:

### 1. Start Backend Server A (Node.js REST API)
```bash
node server.js
# Runs on http://10.7.22.2:3001
# Returns: {"status":"ok","backend":"A","server_port":3001}
```

### 2. Start Backup DNS Resolver (Extension A)
```bash
sudo dnsmasq -C configs/dnsmasq_backup.conf -d
```
- Resolves `app.team1.test` to `10.7.23.158`
- Answers queries when Mac 1 Primary DNS is offline.

### 3. Apply Service Isolation Firewall Rules (Extension C)
```bash
# Enable firewall with isolation rules:
sudo pfctl -e -f configs/pf_backend_isolation.conf

# To view active rules:
sudo pfctl -s rules

# To rollback / disable firewall after demonstration:
sudo pfctl -d
```
- **Rule behavior**: Only Mac 2 (`10.7.23.158`) can connect to port `3001`.
- When client Mac 4 curls `http://10.7.22.2:3001`, connection is blocked/timed out!

### 4. Standby Edge Gateway (Extension E)
```bash
sudo nginx -c $(pwd)/configs/nginx.conf
```
- Listens on `8443` (HTTPS) and `8080` (HTTP).
- When DNS is updated to point `app.team1.test` to `10.7.22.2`, this standby edge serves traffic directly!

---

## 🎯 Phase 2 Evaluation Sequences for Mac 3

### Extension A: Backup DNS Resolver Demonstration
1. When evaluator asks to test DNS resilience:
   - Mac 1 shuts down primary DNS (`sudo pkill dnsmasq`).
   - Mac 3 backup DNS receives and resolves queries from clients seamlessly.
2. Query verification:
   ```bash
   dig @10.7.22.2 app.team1.test
   ```

### Extension C: Service Isolation Demonstration
1. Ensure `pf` rules are active:
   ```bash
   sudo pfctl -s rules
   ```
2. Evaluator checks:
   - Request from Mac 2 Edge (`curl http://10.7.22.2:3001/api/status`): **PASSES**
   - Request directly from Mac 4 Client (`curl http://10.7.22.2:3001/api/status`): **BLOCKED / TIMEOUT**
3. Restore firewall rules after demonstration:
   ```bash
   sudo pfctl -d
   ```

### Extension D: Backend High-Availability Failover
1. Evaluator asks to simulate Backend A failure:
   ```bash
   pkill -f "node server.js"
   ```
2. Client sends continuous requests to Mac 2; Mac 2 detects 3001 is down and routes all traffic to Backend B (`10.7.21.68:3002`) with zero errors.
3. Restart Backend A:
   ```bash
   node server.js &
   ```
4. Load balancing immediately resumes alternating between A and B!

### Extension E: Standby Edge Cutover
1. Start Standby Nginx on Mac 3.
2. In `configs/dnsmasq_backup.conf`, update `address=/app.team1.test/10.7.22.2`.
3. Reload dnsmasq: `sudo pkill -HUP dnsmasq`.
4. Observe client traffic migrating to Mac 3 after TTL (30s) expires.
