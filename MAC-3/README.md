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
