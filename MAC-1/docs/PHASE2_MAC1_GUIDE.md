> **Note (24 Nov 2026):** this guide was written before Phase 2 testing and may show old IPs (`10.7.21.249`, `10.7.23.158`, `10.7.22.2`, `10.7.21.68`) or placeholders (`10.7.8.x`). Current IPs: [`team.env`](../../team.env). Current setup and results: [`CONFIGURATION_BUNDLE.md`](../../docs/CONFIGURATION_BUNDLE.md) and [`PHASE2_REPORT.md`](../../docs/PHASE2_REPORT.md).

# Mac 1: Phase 2 Primary DNS Guide
## Harden, Recover, and Troubleshoot

**Machine Role**: Primary Authoritative & Recursive DNS Server + Test Client  
**Assigned LAN IP**: `10.7.21.249` (Port 53 UDP/TCP)  
**Assigned Domain**: `app.team1.test`, `api.team1.test`, `team1.test`  
**Primary Edge IP**: `10.7.23.158` (Mac 2)  
**Backup DNS & Standby Edge IP**: `10.7.22.2` (Mac 3)  

---

## 🚀 Service Startup & Management

### Start Primary DNS Server
```bash
cd MAC-1
sudo ./scripts/phase2_dns_failover_demo.sh start
```

### Check Running Status & Query Resolution
```bash
./scripts/phase2_dns_failover_demo.sh status
```

---

## 🎯 Phase 2 Demonstration Steps for Mac 1

### Extension A: Backup DNS Failover Demonstration
When the evaluator asks to demonstrate DNS failure resilience:
1. **Stop Primary DNS**:
   ```bash
   sudo ./scripts/phase2_dns_failover_demo.sh stop
   ```
2. Notify the team: Mac 4 client will query `app.team1.test` and demonstrate that queries automatically succeed via Mac 3 Backup DNS (`10.7.22.2`).
3. **Restart Primary DNS**:
   ```bash
   sudo ./scripts/phase2_dns_failover_demo.sh start
   ```

### Extension B & E: TTL & Controlled Record Cutover
When demonstrating DNS TTL behavior or standby edge migration:
1. **Cutover to Standby Edge**:
   ```bash
   sudo ./scripts/phase2_ttl_cutover_demo.sh cutover-standby
   ```
   This changes `app.team1.test` to point to Mac 3 (`10.7.22.2`).
2. Show that clients observe TTL countdown (30s) before migrating, or immediately switch after cache flush.
3. **Restore to Primary Edge**:
   ```bash
   sudo ./scripts/phase2_ttl_cutover_demo.sh restore-primary
   ```
   This restores `app.team1.test` back to Mac 2 (`10.7.23.158`).
