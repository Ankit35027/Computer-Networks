> **Note (24 Nov 2026):** this guide was written before Phase 2 testing and may show old IPs (`10.7.21.249`, `10.7.23.158`, `10.7.22.2`, `10.7.21.68`) or placeholders (`10.7.8.x`). Current IPs: [`team.env`](../team.env). Current setup and results: [`CONFIGURATION_BUNDLE.md`](../docs/CONFIGURATION_BUNDLE.md) and [`PHASE2_REPORT.md`](../docs/PHASE2_REPORT.md).

# Mac 3: Backend Server A

**Machine Role**: Backend Server A (Port 3001) + Backup DNS Resolver  
**Services Running**: Node.js REST API (`server.js`), Backup `dnsmasq`  
**LAN IP**: `10.7.22.2`  

---

## 🚀 Quick Start Guide

### 1. Start Backend Server A (Node.js REST API)
```bash
# Install dependencies (if needed)
npm install

# Start Backend A server on port 3001
node server.js
```
The server will start listening on port `3001` and return JSON responses with response header `X-Backend: A`.

### 2. Verify Endpoint Locally
```bash
curl http://10.7.22.2:3001/api/status
```
Expected response:
```json
{"status": "ok", "backend": "A", "server_port": 3001}
```

---

## 📁 Directory Structure
- `server.js` — Main Express REST API server for Backend A
- `configs/` — Backup `dnsmasq` configuration & `pf` firewall rules for Phase 2 service isolation
- `certs/` — TLS certificates & local Root CA copies
- `evidence/` — Screenshots & verification logs for Backend A
