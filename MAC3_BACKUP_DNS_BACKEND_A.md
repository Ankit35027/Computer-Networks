# Mac 3: Backup DNS, Backend A & Standby Edge Guide

**Machine Role**: Backup DNS Resolver (Extension A), Upstream REST Backend A (Port 3001), Service Isolation Firewall Node (Extension C), Standby Edge Gateway (Extension E)  
**Assigned Subnet IP**: `10.7.8.30` (or assigned LAN IP)  

---

## 1. Extension A: Backup DNS Resolver Setup
Copy `configs/dnsmasq_backup.conf` from Mac 2 to Mac 3 and start the secondary DNS server:
```bash
sudo dnsmasq -C /path/to/dnsmasq_backup.conf -d
```
*Note*: Client machines (Mac 2 and Mac 4) must list Mac 1 (`10.7.8.10`) as Primary DNS and Mac 3 (`10.7.8.30`) as Secondary DNS.

---

## 2. Upstream Application Server A Setup
Copy `backends/backend_a.py` to Mac 3. Start Backend A on Port 3001:
```bash
python3 backends/backend_a.py --port 3001
```
Verify locally:
```bash
curl http://127.0.0.1:3001/api/status
```
**Expected Output**: `{"status": "ok", "backend": "A", "server_port": 3001}`

---

## 3. Extension C: Service Isolation (Backend Firewall Rules)
Apply macOS Packet Filter (`pf`) firewall rules to block direct external traffic to port 3001 except from Mac 2 Edge Proxy (`10.7.8.201`):
```bash
# Enable firewall with isolation rules:
sudo pfctl -e -f configs/pf_backend_isolation.conf

# To disable/restore firewall after demonstration:
sudo pfctl -d
```
**Demonstration**:
- Request from Mac 2 (`https://app.team1.test:8443`) -> **SUCCEEDS**
- Direct request from Mac 4 (`http://<Mac3_IP>:3001`) -> **BLOCKED / TIMEOUT**

---

## 4. Extension E: Standby Edge Proxy Setup
Copy `configs/nginx.conf` and `certs/` to Mac 3 to host a standby edge proxy.  
When updating DNS record on Mac 1/3 to point `app.team1.test` to Mac 3 IP, clients will seamlessly cut over after 30-second TTL expiry.
