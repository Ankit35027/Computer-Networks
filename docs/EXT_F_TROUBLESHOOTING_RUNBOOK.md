# Extension F – Troubleshooting Runbook (Team 1)

**Rule:** diagnose **top-down by layer, one layer at a time**, and say out loud
what you test, what you expect, what you see, and what that rules out.
Never "restart everything"; find the **first failing layer** and fix only that.

Run from the client (Mac 4), repo root:

```bash
./scripts/diagnose.sh                    # full sweep: L0 → DNS → TCP → TLS → HTTP
./scripts/diagnose.sh --ip 10.7.31.100   # bypass DNS: if this works but the normal run fails → DNS fault
```

IPs come from `team.env`: Mac 1 DNS `10.7.5.14` · Mac 2 edge `10.7.31.100` · Mac 3 backend A / backup DNS / standby edge `10.7.13.57` · Mac 4 backend B `10.7.17.220`.

---

## 1. The method: one command per layer

| # | Layer | Question | Manual command (Mac 4) | Healthy result |
|---|---|---|---|---|
| 0 | Link / IP | Am I on the LAN? Is the host alive? | `ipconfig getifaddr en0` · `ping -c2 10.7.31.100` | own 10.7.x.x IP, replies |
| 1 | DNS (app, UDP 53) | Does the name resolve, **to the right IP**? | `dscacheutil -q host -a name app.team1.test` · `dig @10.7.5.14 app.team1.test` · `dig @10.7.13.57 app.team1.test` · `cat /etc/hosts` | `10.7.31.100` from all |
| 4 | TCP (transport) | Is something listening on the port? | `nc -G3 -vz 10.7.31.100 8443` | `succeeded!` |
| 5/6 | TLS | Handshake OK? Cert trusted and right name? | `openssl s_client -connect 10.7.31.100:8443 -servername app.team1.test -CAfile MAC-2/certs/ca.crt </dev/null \| grep -E "subject=\|Verify return"` · `curl -v https://app.team1.test:8443/ 2>&1 \| grep -i "ssl\|certificate"` | `Verify return code: 0 (ok)`, `SSL certificate verify ok` |
| 7 | HTTP / application | Does the edge get a backend answer? | `curl -si https://app.team1.test:8443/api/status \| grep -iE "^HTTP\|x-edge\|x-backend"` | `HTTP/2 200`, `x-backend: A/B` |
| 7b | Behind the edge | Are the backends alive? (run **on Mac 2**, the edge is allowed through pf) | `nc -G3 -vz 10.7.13.57 3001` · `nc -G3 -vz 10.7.17.220 3002` · `tail -5 /tmp/nginx_mac2_error.log` | both `succeeded!` |

**Two error words that tell you the layer at once:**
- `Connection refused`: the host is **alive**, but nothing is listening on that port (service stopped or wrong port). The host answered with a TCP RST (or ICMP port-unreachable for UDP/DNS).
- `Operation timed out`: **no answer at all**. The packet was dropped (pf firewall), or the host is down or unreachable.

---

## 2. Symptom → layer → cause → fix

| What the client sees | First failing layer | Likely injected fault | How to confirm | Fix |
|---|---|---|---|---|
| `curl: (6) Could not resolve host` | L1 DNS | dnsmasq stopped on Mac 1 **and** Mac 3 / client DNS changed / Wi-Fi DNS overridden (WARP, DHCP) | `dig @10.7.5.14 …` → timed out or refused; `scutil --dns` | restart dnsmasq; `/etc/resolver/team1.test` or `networksetup -setdnsservers Wi-Fi 10.7.5.14 10.7.13.57`; disconnect WARP |
| Resolves to a **wrong IP**, then timeout or refused | L1 DNS (record) | wrong `address=` in dnsmasq.conf, or a stale `/etc/hosts` line | `dig @10.7.5.14` vs `dig @10.7.13.57` disagree; `grep team1 /etc/hosts` | correct the record on **both** DNS servers + restart dnsmasq; flush the client cache |
| Old IP still used after a record fix | L1 DNS (cache) | client cache, TTL 30 s | `dscacheutil -q host …` differs from `dig @server` | wait for the TTL, or `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` |
| `Connection refused` on 8443 | L4 TCP | nginx stopped on Mac 2 / nginx listening on another port | Mac 2: `pgrep nginx`, `sudo lsof -nP -iTCP:8443 -sTCP:LISTEN` | `./MAC-2/scripts/start_nginx.sh start`; fix `listen` |
| `Operation timed out` on 8443 | L4 TCP / L3 | pf on Mac 2 blocking 8443 / Mac 2 off the Wi-Fi / IP changed | `ping 10.7.31.100`; Mac 2: `sudo pfctl -s info`, `sudo pfctl -a com.apple/cn-isolation -sr` | `sudo ./scripts/pf_isolation.sh disable`; update `team.env` + configs (`./scripts/check_ips.sh`) |
| `curl: (60) SSL certificate problem: unable to get local issuer` | L5/6 TLS (trust) | Root CA removed from the client keychain / client given a different CA | `security find-certificate -c "Team1" -Z /Library/Keychains/System.keychain` | `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain MAC-4/certs/ca.crt` |
| `SSL: no alternative certificate subject name matches` | L5/6 TLS (name) | accessed by IP or wrong hostname / wrong cert in nginx | `openssl s_client … \| grep subject` | use `https://app.team1.test:8443`; restore `ssl_certificate` |
| TLS handshake failure / nginx won't start | L5/6 TLS (server) | cert/key path wrong or key mismatch in nginx.conf | Mac 2: `nginx -t -c $PWD/MAC-2/configs/nginx.conf` | fix the paths (`../certs/server.crt`, `../certs/server.key`) |
| `HTTP/2 502 Bad Gateway` | L7 (edge → backend) | **both** backends stopped / wrong upstream IP or port / pf on backends blocks the edge | Mac 2: `nc -vz` to 3001/3002; `tail /tmp/nginx_mac2_error.log` → `connect() failed (61)` = refused, `(60)` = timed out | start the backends; fix the `upstream` lines; allow the edge in pf |
| `504 Gateway Timeout` | L7 | backend hung / packets dropped between edge and backend | error log `upstream timed out` | restart the backend; check pf |
| Only `x-backend: B`, never A | L7 (pool degraded) | Backend A down (Ext D failover is hiding it) | error log `upstream server temporarily disabled` | start Backend A on Mac 3 |
| `304` demo returns `200` | L7 (app) | ETag differs between backends / request sent without `If-None-Match` | `curl -sI …/cached \| grep -i etag` on several requests | same `/cached` code on both backends |
| `HTTP 404` | L7 (app) | wrong path | check the URL (`/api/status`, `/cached`) | — |

---

## 3. How to say it out loud (template)

> "First I check **DNS**: `dig @10.7.5.14 app.team1.test` gives 10.7.31.100, which is correct, so DNS is fine.
> Next, **TCP**: `nc -vz 10.7.31.100 8443` gives *connection refused*. The host is alive but nothing listens on 8443, so the fault is at the **transport/service layer on the edge**.
> On Mac 2, `pgrep nginx` shows nothing, so nginx is stopped. I start it, then re-test from the top: DNS ✓, TCP ✓, TLS verify ok ✓, HTTP 200 ✓."

---

## 4. Practice drills (one teammate breaks it, another diagnoses with only the runbook)

| Drill | Inject (on) | Expected first failing layer | Restore |
|---|---|---|---|
| D1 Wrong DNS record | Mac 1 + Mac 3: `sed -i '' 's\|^address=/app.team1.test/.*\|address=/app.team1.test/10.7.5.14\|' <conf>` + restart dnsmasq | L1 (wrong IP) → then L4 refused | `git checkout -- <conf>` + restart dnsmasq; flush on Mac 4 |
| D2 Edge down | Mac 2: `./MAC-2/scripts/start_nginx.sh stop` | L4 refused | `./MAC-2/scripts/start_nginx.sh start` |
| D3 Both backends down | Mac 3: `pkill -f "node server.js"`; Mac 4: `pkill -f backend_b.py` | L7 502 | restart both backends |
| D4 Both DNS servers down | Mac 1 + Mac 3: `sudo pkill -x dnsmasq` | L1 (cannot resolve) | restart both dnsmasq |
| D5 Edge blocked from a backend | Mac 4: pf rule without the edge (see note) | L7 → B removed from the pool (only A served); 502 if A is also down | `sudo ./scripts/pf_isolation.sh disable` |
| D6 Client CA trust removed | Mac 1 (second client): `sudo security delete-certificate -c "Team1 Local Root CA" /Library/Keychains/System.keychain` | L5/6 (curl 60) | re-add the CA (see the table) |

Write down for each drill: the time, the symptom seen, the commands run in order, the layer identified, the fix, and the time to fix. These go into the Phase 2 report as the "troubleshooting findings".

## 5. Real faults we already hit (use these as report material)
| Fault | Layer | How we found it |
|---|---|---|
| Mac 4 resolved via 8.8.8.8 even after `networksetup` (Cloudflare WARP + DHCP DNS override) | L1 | `dig` showed `SERVER: 8.8.8.8`; `scutil --dns` showed `Default: DHCP-en0` → fixed with `/etc/resolver/team1.test` |
| Mac 4 trusted the **leaf** cert, not the Root CA → curl 60 | L5/6 | `security find-certificate` showed the hash `538E…` = server.crt → removed it, trusted `E02B…` (Root CA) |
| `curl -I` returned **501** from Backend B | L7 | Python `BaseHTTPRequestHandler` had no `do_HEAD` → added HEAD support |
| Standby edge not started (cert path) → DNS cutover caused an outage | L4/L5 | `served-by=NONE` after cutover; `nginx -t` error on Mac 3 → **always health-check the target before a DNS cutover** |
| nginx round-robin uneven `A A A B B A` | L7 | each worker had its own counter → `zone backend_cluster 1m;` |
