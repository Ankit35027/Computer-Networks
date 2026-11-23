# Final Demonstration Script (Section 8, 11 steps)

Main client: **Mac 4** (`~/Downloads/Computer-Networks`). Step 3 runs on **Mac 1** because its system DNS is the team DNS (Mac 4 uses a per-domain resolver; see PHASE2_REPORT §5).
Each step lists a fallback file if the live run fails. Target: under 15 minutes.

## Pre-flight (10 minutes before)

| Mac | Command | Expect |
|---|---|---|
| all | `ipconfig getifaddr en0` | same IPs as `team.env`; if not, update `team.env` + `./scripts/check_ips.sh` |
| all | Cloudflare WARP / VPN **off** | |
| Mac 1 | `sudo /opt/homebrew/sbin/dnsmasq --conf-file="$PWD/MAC-1/configs/dnsmasq.conf"`; `dig app.team1.test +short` | `10.7.31.100` |
| Mac 3 | `sudo /opt/homebrew/sbin/dnsmasq --conf-file="$PWD/MAC-3/configs/dnsmasq_backup.conf"`; `cd MAC-3 && nohup node server.js > /tmp/backend_a.log 2>&1 &`; `cd .. && nginx -c "$PWD/MAC-3/configs/nginx.conf"` | backup DNS, Backend A, standby edge up |
| Mac 4 | `nohup python3 -u MAC-4/backend/backend_b.py > /tmp/backend_b.log 2>&1 &` | Backend B up |
| Mac 2 | `./MAC-2/scripts/start_nginx.sh start` | `Nginx started successfully` |
| Mac 4 | `./scripts/diagnose.sh \| tail -1` | `VERDICT: all layers healthy.` |
| Mac 1 | `curl -s -o /dev/null -w '%{http_code}\n' https://app.team1.test:8443/api/status` | `200` (if curl 60: trust `MAC-2/certs/ca.crt` in the System keychain) |

## The 11 steps

| # | Step | Mac | Command | What to point at | Fallback evidence |
|---|---|---|---|---|---|
| 1 | Topology and inventory | any | open `ARCHITECTURE.md`, `docs/PHASE2_REPORT.md` §1 | IP table, role of each Mac, Phase 2 additions | — |
| 2 | All Macs on the LAN | Mac 4 | `./scripts/diagnose.sh \| sed -n '/L0/,/L1/p'` | own IP + ping to all 4 Macs | `S0_*` screenshots |
| 3 | Resolve the domain via team DNS | **Mac 1** | `dig app.team1.test` | `ANSWER: app.team1.test. 30 IN A 10.7.31.100`, `SERVER: 127.0.0.1` (Mac 1's dnsmasq) | `S1_01` |
|   | (same from Mac 4) | Mac 4 | `dig @10.7.5.14 app.team1.test` · `dscacheutil -q host -a name app.team1.test` · `scutil --dns \| grep -A3 team1.test` | resolver for `team1.test` = 10.7.5.14, 10.7.13.57 | `ExtA_06` |
| 4 | HTTPS by name, no warning | Mac 4 | `curl -v https://app.team1.test:8443/api/status 2>&1 \| grep -E "SSL certificate verify\|^< HTTP"` (or Safari) | `SSL certificate verify ok`, `HTTP/2 200`, no `-k`, no IP in the URL | `P1_TaskG` |
| 5 | Load balancing | Mac 4 | `for i in 1 2 3 4 5 6; do curl -s -D - -o /dev/null https://app.team1.test:8443/api/status \| grep -i x-backend; done` | A, B, A, B… | `extD_ha_failover` first lines |
| 6 | Wireshark DNS/TCP/TLS | Mac 4 | `open -a Wireshark MAC-4/evidence/phase1_final/full_flow_dns_tcp_tls_*.pcap` · filters `dns`, `tcp.flags.syn==1`, `tls.handshake` (Decode As TCP 8443 → TLS) | query/response UDP 53, SYN / SYN-ACK / ACK to 8443 with ephemeral port, ClientHello SNI `app.team1.test`, ServerHello, encrypted data | `P1_TaskG` |
| 7 | Headers + 304 | Mac 4 | `curl -sI https://app.team1.test:8443/cached \| grep -iE "^HTTP\|cache-control\|etag\|x-backend"` then `curl -sI -H 'If-None-Match: "9af6612c5e2813472332c7829fa53899"' https://app.team1.test:8443/cached \| head -1` | `cache-control: public, max-age=60`, `etag`, then `HTTP/2 304` (from A or B) | — |
| 8 | Fail Backend A | Mac 3 → Mac 4 | Mac 3: `pkill -f "node server.js"`; Mac 4: step 5 loop → only B, all 200; Mac 2: `tail -3 /tmp/nginx_mac2_error.log`; restart A | `connect() failed (61)`, `temporarily disabled`; SPOF = Mac 2 nginx | `ExtD_*` |
| 9 | Phase 2 DNS behaviour | Mac 1, 3, 4 | **Ext A:** Mac 1 `sudo pkill -x dnsmasq` → Mac 4 `dig @10.7.5.14 app.team1.test +time=2 +tries=1` (timeout), `dig @10.7.13.57 …` (answer), `curl …/api/status` (200) → restart Mac 1. **Ext B/E (optional):** cutover script from PHASE2_REPORT §2.5 | backup answers while primary is down; TTL lag then `x-edge: mac3-standby` | `ExtA_06`, `ExtBE_05` |
| 10 | Faculty-injected fault | Mac 4 | `./scripts/diagnose.sh`, then the manual command for the failing layer from the runbook; say each step aloud | first failing layer → cause → fix → re-run until healthy | `ExtF_D2`, `ExtF_D3` |
| 11 | Viva | all | — | every member explains the full request path, not only their Mac | runbook §3, report §4 |

## After the demo
Restore everything: `./scripts/pf_isolation.sh disable` (Mac 3/4, if pf was used), `git checkout -- MAC-1/configs/dnsmasq.conf MAC-3/configs/dnsmasq_backup.conf` + restart dnsmasq (if a cutover was shown).
