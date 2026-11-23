# Configuration Bundle (Phase 1 + Phase 2)

All IPs come from [`team.env`](../team.env). After an IP change run `./scripts/check_ips.sh`; it lists every config line that must be updated.

## 1. Files

| Component | File | Runs on | Phase |
|---|---|---|---|
| Team IPs (single source) | `team.env` | all | 2 |
| Primary DNS | `MAC-1/configs/dnsmasq.conf` | Mac 1 | 1 (TTL 30 s used in 2) |
| Backup DNS (mirror of primary) | `MAC-3/configs/dnsmasq_backup.conf` | Mac 3 | 2 (Ext A) |
| Primary edge (TLS + load balancer) | `MAC-2/configs/nginx.conf` | Mac 2 | 1, + `zone`, `X-Edge` in 2 |
| Standby edge | `MAC-3/configs/nginx.conf` | Mac 3 | 2 (Ext E) |
| TLS: Root CA / server cert / key | `MAC-2/certs/ca.crt`, `server.crt`, `server.key`, `openssl_san.cnf`, `generate_certs.sh` | edges (cert+key), clients (CA) | 1 |
| Backend A | `MAC-3/server.js` (Node/Express, :3001) | Mac 3 | 1 (+ `/cached` in 2) |
| Backend B | `MAC-4/backend/backend_b.py` (Python, :3002) | Mac 4 | 1 (+ `/cached`, HEAD in 2) |
| Firewall (pf) | `scripts/pf_isolation.sh` (generates the rules) | Mac 3, Mac 4 | 2 (Ext C) |
| Client resolver (Mac 4) | `/etc/resolver/team1.test` | Mac 4 | 2 |
| Diagnosis | `scripts/diagnose.sh`, `docs/EXT_F_TROUBLESHOOTING_RUNBOOK.md` | client | 2 (Ext F) |
| TTL / cutover helper | `MAC-1/scripts/phase2_ttl_cutover_demo.sh` | Mac 1 | 2 (Ext B/E) |

## 2. TLS certificate setup notes
1. `MAC-2/certs/generate_certs.sh` creates a private **Root CA** (`ca.key`, `ca.crt`, CN "Team1 Local Root CA", 10 years) and a **server certificate** for `app.team1.test`, signed by that CA. SANs: `app.team1.test`, `api.team1.test`, `team1.test`, `*.team1.test`, `127.0.0.1` (from `openssl_san.cnf`).
2. nginx (both edges) loads `server.crt` + `server.key`; TLS 1.2/1.3, HTTP/2.
3. Each **client** trusts only the **Root CA** (never the server cert):
   `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain MAC-2/certs/ca.crt`
   Check: `security find-certificate -c "Team1 Local Root CA" -Z /Library/Keychains/System.keychain` → SHA-256 `E02BE070…`.
4. Verify without `-k`: `curl -v https://app.team1.test:8443/api/status` → `SSL certificate verify ok`.
5. The standby edge reuses the **same** cert and key, so clients see no warning after a DNS cutover.
All files are PEM text. Private keys are in the repo only because this is a closed lab.

## 3. Launch instructions (repo root on each Mac)

| Mac | Start | Stop | Check |
|---|---|---|---|
| Mac 1 | `sudo /opt/homebrew/sbin/dnsmasq --conf-file="$PWD/MAC-1/configs/dnsmasq.conf"` | `sudo pkill -x dnsmasq` | `dig @127.0.0.1 app.team1.test` |
| Mac 3 (DNS) | `sudo /opt/homebrew/sbin/dnsmasq --conf-file="$PWD/MAC-3/configs/dnsmasq_backup.conf"` | `sudo pkill -x dnsmasq` | `dig @127.0.0.1 app.team1.test` |
| Mac 3 (Backend A) | `cd MAC-3 && npm install && nohup node server.js > /tmp/backend_a.log 2>&1 &` | `pkill -f "node server.js"` | `curl http://127.0.0.1:3001/api/status` |
| Mac 3 (standby edge) | `nginx -c "$PWD/MAC-3/configs/nginx.conf"` | `nginx -s stop -c "$PWD/MAC-3/configs/nginx.conf"` | `curl --resolve app.team1.test:8443:127.0.0.1 -sI https://app.team1.test:8443/api/status` |
| Mac 4 (Backend B) | `nohup python3 -u MAC-4/backend/backend_b.py > /tmp/backend_b.log 2>&1 &` | `pkill -f backend_b.py` | `curl http://127.0.0.1:3002/api/status` |
| Mac 2 (edge) | `./MAC-2/scripts/start_nginx.sh start` (`reload`, `stop`) | `./MAC-2/scripts/start_nginx.sh stop` | `nc -vz <MAC3_IP> 3001`, `nc -vz <MAC4_IP> 3002` |

Start order: DNS → backends → edges. Logs: `/tmp/nginx_mac2_{access,error}.log`, `/tmp/nginx_mac3_standby_*.log`, `/tmp/dnsmasq_primary.log`, `/tmp/dnsmasq_backup.log`.

### Client DNS
- Mac 1: `sudo networksetup -setdnsservers Wi-Fi 127.0.0.1 <MAC3_IP>`
- Mac 2: `sudo networksetup -setdnsservers Wi-Fi <MAC1_IP> <MAC3_IP>`
- Mac 4 (DHCP DNS overrides the Wi-Fi setting): `printf "nameserver <MAC1_IP>\nnameserver <MAC3_IP>\ntimeout 2\n" | sudo tee /etc/resolver/team1.test`
- Undo: `sudo networksetup -setdnsservers Wi-Fi Empty`, `sudo rm /etc/resolver/team1.test`

## 4. Firewall rules (Ext C)
`sudo ./scripts/pf_isolation.sh enable 3001` (Mac 3) / `enable 3002` (Mac 4) loads into anchor `com.apple/cn-isolation`:
```
pass  in quick on lo0 proto tcp from any to any port <port>
pass  in quick proto tcp from { <MAC2_IP>, <MAC3_IP> } to any port <port>
block drop in quick proto tcp from any to any port <port>
```
- `/etc/pf.conf` is never modified; the original pf state is backed up to `/var/tmp/cn-isolation/backup_*.txt` before enabling.
- **Rollback:** `sudo ./scripts/pf_isolation.sh disable` (flushes the anchor and releases our pf enable token).
- Status: `sudo ./scripts/pf_isolation.sh status`.
