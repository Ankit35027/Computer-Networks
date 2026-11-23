# Phase 2 Final Report: Harden, Recover, and Troubleshoot
**Team 1 · Private Network Service Platform · `app.team1.test`**
Tests run live on the 4 team Macs, 23–24 Nov 2026, campus Wi-Fi `10.7.0.0/19` (gateway `10.7.0.1`).
Every result below is backed by a log, pcap or screenshot; the file is named in each section.
Screenshot index: [`evidence/screenshots/README.md`](../evidence/screenshots/README.md).

**Contents:** 1. What changed from Phase 1 · 2. Resilience tests and results · 3. Troubleshooting findings · 4. Learning summary (one paragraph per extension) · 5. Limitations

---

## 1. What changed from Phase 1

| Area | Phase 1 | Phase 2 |
|---|---|---|
| IP management | IPs hard-coded in ~30 files; DHCP changed them between sessions | **`team.env`** holds the four IPs in one place; scripts read it; `scripts/check_ips.sh` flags any config that disagrees |
| DNS | one dnsmasq on Mac 1 | + **backup dnsmasq on Mac 3** with identical records; clients list both (Ext A) |
| Edge | one nginx on Mac 2 | + **standby nginx on Mac 3**, same certificate and same backend pool; `X-Edge` header shows which edge answered (Ext E) |
| Load balancer | round-robin, per-worker state (uneven `A A A B B A`) | `zone backend_cluster 1m;` gives shared state → strict A/B alternation and consistent failover (Ext D) |
| Backends | reachable directly by any client | **pf firewall anchor** on Mac 3 / Mac 4: only the edge(s) may connect (Ext C) |
| Caching | 304 worked only on Backend A (different ETag on B) | identical `/cached` body and ETag on both backends; Backend B gained `HEAD` support (`curl -I` returned 501 before) |
| TLS trust | Mac 4 trusted the server leaf cert; demos used `-k` / `--cacert` | Mac 4 and Mac 1 trust the **Root CA** in the System keychain; plain `curl https://app.team1.test:8443` verifies |
| Troubleshooting | script fell back to `127.0.0.1` and `-k` | `scripts/diagnose.sh` (L0→DNS→TCP→TLS→HTTP, LAN-aware) + [runbook](EXT_F_TROUBLESHOOTING_RUNBOOK.md) |

### Final topology

| Mac | IP | Services (Phase 2) | Ports |
|---|---|---|---|
| Mac 1 | 10.7.5.14 | primary DNS (dnsmasq), test client | 53 |
| Mac 2 | 10.7.31.100 | **primary edge**: nginx TLS termination + load balancer | 8443, 8080 |
| Mac 3 | 10.7.13.57 | Backend A, **backup DNS**, **standby edge**, pf isolation | 3001, 53, 8443 |
| Mac 4 | 10.7.17.220 | Backend B, pf isolation, **main test client** | 3002 |

```
 client (Mac 4) ──DNS UDP 53──► Mac 1 dnsmasq (primary)   ┐ same records,
        │        └─(fallback)─► Mac 3 dnsmasq (backup)    ┘ TTL 30 s
        │ HTTPS 8443 (TLS 1.3, h2)
        ▼
 Mac 2 nginx  (primary edge)      Mac 3 nginx (standby edge, same cert)
        │ round-robin, zone, passive health check, retry
        ├──HTTP──► Mac 3 :3001 Backend A   ┐ pf: only 10.7.31.100 and
        └──HTTP──► Mac 4 :3002 Backend B   ┘ 10.7.13.57 may connect
```

---

## 2. Resilience tests and results
Each test was run live on the LAN. Times are from the logs named in each subsection.

### 2.1 Extension A: Backup DNS resolver

**Setup.** `MAC-3/configs/dnsmasq_backup.conf` is an exact mirror of Mac 1's records (`app/api/team1.test → 10.7.31.100`, `local-ttl=30`). It does not forward to Mac 1, so it can answer on its own. Clients list both servers: Mac 1 `127.0.0.1, 10.7.13.57`; Mac 2 `10.7.5.14, 10.7.13.57`; Mac 4 uses `/etc/resolver/team1.test` with the same two servers (see §5 for why).

**Test** (`MAC-4/evidence/phase2/extA_backup_dns_20261123_2352.log` + `.pcap`):

| Time | Observation |
|---|---|
| 23:52:35 | primary `10.7.5.14 → 10.7.31.100`, backup `10.7.13.57 → 10.7.31.100` |
| — | dnsmasq stopped on Mac 1 |
| 23:53:53 | primary **timed out**; backup → `10.7.31.100`; system resolver → `10.7.31.100`; **HTTPS `code=200` in 0.33 s** |
| pcap | `10.7.5.14 > 10.7.17.220: ICMP 10.7.5.14 udp port 53 unreachable`, then the query goes to `10.7.13.57.53` and is answered |

### 2.2 Extension B: DNS TTL and controlled record change

**Setup.** `local-ttl=30` on both DNS servers. The record is changed on **both** servers (Mac 1 with `MAC-1/scripts/phase2_ttl_cutover_demo.sh`, Mac 3 with `sed`), and dnsmasq is **restarted**, because SIGHUP does not reload `address=` lines.

**Test, run 1** (`…_0024_run1_TTL_ok_standby_not_ready.log`, screenshot `ExtB_01`):

| Time | DNS server (Mac 1) | Mac 4 cache |
|---|---|---|
| 00:25:47 | 10.7.31.100 | 10.7.31.100 |
| **00:25:50** | **10.7.13.57** (changed) | 10.7.31.100 (still old) |
| 00:26:09 | 10.7.13.57 | 10.7.31.100 (still old) |
| **00:26:13** | 10.7.13.57 | **10.7.13.57** (cache expired, ~23 s) |

**Test, run 2** (`…_0030_run2_FINAL.log`, screenshot `ExtBE_05`): the change at 00:32:00 reached the cache at 00:32:03 (~3 s). After the record was restored (00:32:52), the cache was still stale (`10.7.13.57`); **`sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`** switched it at once (00:32:54 → `10.7.31.100`).

### 2.3 Extension C: Service isolation (backend firewall)

**Setup.** `scripts/pf_isolation.sh enable 3001` (Mac 3) / `enable 3002` (Mac 4). Rules go only into the sub-anchor `com.apple/cn-isolation`, which the stock macOS ruleset already evaluates. **`/etc/pf.conf` is never modified.** pf is enabled with a reference token (`pfctl -E`) so rollback restores the original state. The rules:

```
pass  in quick on lo0 proto tcp from any to any port 3001
pass  in quick proto tcp from { 10.7.31.100, 10.7.13.57 } to any port 3001   # primary + standby edge
block drop in quick proto tcp from any to any port 3001
```

**Test** (`MAC-1/evidence/phase2/extC_client_view_20261123_2359.log`, `MAC-2/evidence/phase2/extC_edge_view_0009.log`, `MAC-4/evidence/phase2/extC_e2e_0009.log`, `MAC-3/evidence/phase2/ and MAC-4/evidence/phase2/extC_enable_0006.log`):

| Time | From | Result |
|---|---|---|
| 00:01:33 | Mac 1 (client) BEFORE | 3001 and 3002 `succeeded!` (anyone could bypass the edge) |
| 00:06 | Mac 3, Mac 4 | rules enabled, pf `Status: Enabled` |
| 00:08:59 | Mac 1 (client) | 3001 and 3002 **`Operation timed out`** |
| 00:09:08 | Mac 2 (edge) | 3001 and 3002 `succeeded!`, Backend A JSON returned |
| 00:09:14 | Mac 4 (client) | direct 3001 **timed out**; through the edge `HTTP/2 200`, B, A, B, A |
| rollback | Mac 3, Mac 4 | `ROLLED BACK`, anchor empty, pf back to `Disabled` (original state) |
| 00:12:19 | Mac 1 | 3001 and 3002 `succeeded!` again (rollback proven) |

**Rollback:** `sudo ./scripts/pf_isolation.sh disable`.

### 2.4 Extension D: High-availability failover

**Setup** (`MAC-2/configs/nginx.conf`):
```
upstream backend_cluster {
    zone backend_cluster 1m;
    server 10.7.13.57:3001  max_fails=2 fail_timeout=5s;
    server 10.7.17.220:3002 max_fails=2 fail_timeout=5s;
}
proxy_next_upstream error timeout http_502 http_503 http_504;
proxy_connect_timeout 2s;
```

**Test** (`MAC-4/evidence/phase2/extD_ha_failover_20261123_2341.log`, `extD_recovery_20261123_2344.log`, `MAC-2/evidence/phase2/extD_nginx_*.log`):

| Time | Observation |
|---|---|
| until 23:41:56 | strict B, A, B, A, all 200 |
| 23:41:55 | Backend A stopped on Mac 3 |
| 23:41:58, 23:42:02 | nginx log `upstream: 10.7.13.57:3001, 10.7.17.220:3002` → served by B: tried A, got `connect() failed (61: Connection refused)`, **retried on B inside the same request**. These requests took ~1.2–1.4 s instead of ~0.1 s |
| 23:42:03–08 | only B; error log `upstream server temporarily disabled` (2 failures → A skipped for 5 s) |
| whole run | **60 of 60 client requests returned `code=200`**, zero errors seen by the client |
| 23:44:15+ | A restarted → B, A, B, A again |

### 2.5 Extension E: Controlled edge migration (DNS-based cutover)

**Setup.** `MAC-3/configs/nginx.conf` is the Mac 2 config with only three differences: log/pid names, `X-Edge: mac3-standby`, and the certificate path, which points to **Mac 2's certificate and key** (same `CN=app.team1.test`, same Root CA). Both edges use the same backend pool.

**Test** (`…_0030_run2_FINAL.log`, screenshots `ExtE_01–04`, `ExtBE_05`):

| Time | DNS server | Mac 4 cache | Served by |
|---|---|---|---|
| 00:30:44–00:31:56 | 10.7.31.100 | 10.7.31.100 | **mac2-primary** |
| 00:31:59 / 00:32:04 | record changed on Mac 1 / Mac 3 | | |
| 00:32:00 | 10.7.13.57 | 10.7.31.100 | mac2-primary (cached client still on old edge) |
| **00:32:03–00:32:47** | 10.7.13.57 | 10.7.13.57 | **mac3-standby** (HTTP 200, certificate verified, no warning) |
| 00:32:51 | record restored | | |
| 00:32:52 | 10.7.31.100 | 10.7.13.57 | mac3-standby (stale cache) |
| 00:32:54 | after flush | 10.7.31.100 | **mac2-primary** |

**Seen from the edges' access logs** (screenshots `ExtE_05`, `ExtE_06`): Mac 2 logged Mac 4's last request at **00:32:00**; Mac 3's standby logged Mac 4 from **00:32:03 to 00:32:52**; Mac 2 received it again at 00:32:54 after the restore and flush. No request was lost in between.


**Failure found in run 1:** the standby nginx on Mac 3 had not started (it still pointed at an old certificate path). After the DNS change, clients whose cache expired were sent to a dead edge (`served-by=NONE`). Lesson: **health-check the new target before changing DNS** (`curl --resolve app.team1.test:8443:<new-ip> …`).

### 2.6 Section 6.3 failure scenarios, re-run on the LAN (Mac 4, 24 Nov 00:52; screenshot `P1_6.3_…`)
| Scenario | Observation | Meaning |
|---|---|---|
| Wrong DNS server | `dig @10.7.17.220` → `connection timed out`, but `ping 10.7.31.100` → 1 packet received | DNS and IP connectivity are independent layers |
| Name points to a wrong IP | `Trying 10.7.5.14:8443` → `Connection refused` | DNS is only a directory; it does not check the destination |
| One backend stopped | all requests served by B (Ext D) | edge failover |
| Both backends stopped | `HTTP 502 Bad Gateway`, DNS/TCP/TLS still pass (drill D3) | shows where the edge ends and the backend begins |
| Wrong port | `Trying 10.7.31.100:9999` → `Connection refused` | host reachable; port is a separate identifier |

---

## 3. Troubleshooting findings (Extension F)

### 3.1 Method
 Test one layer at a time from the client, top-down: L0 link/IP → L1 DNS → L4 TCP → L5/6 TLS → L7 HTTP. The first layer that fails is the one to fix. `scripts/diagnose.sh` runs this sequence and prints a verdict; the [runbook](EXT_F_TROUBLESHOOTING_RUNBOOK.md) maps each symptom to its cause and fix.

### 3.2 Practice drills (faculty-style injected faults)

**Drills** (`MAC-4/evidence/phase2/extF_*.log`, screenshots `ExtF_*`):

| Drill | Injected fault | What diagnose.sh showed | Verdict | Fix |
|---|---|---|---|---|
| Baseline 00:38:07 | none | all PASS, `HTTP 200 edge=mac2-primary` | all layers healthy | — |
| D2 00:39:29 | nginx stopped on Mac 2 | ping and DNS PASS, `TCP 10.7.31.100:8443 REFUSED` | **L4** | `start_nginx.sh start` |
| D3 00:41:16 | both backends stopped | DNS, TCP, TLS PASS, `HTTP 502 Bad Gateway`, backends REFUSED | **L7** | restart backends → all layers healthy |

### 3.3 Real faults found during the project

**Real faults found during the project** (each was solved with the same top-down method):

| Symptom | Layer | Cause | Fix |
|---|---|---|---|
| Mac 4 `dig` used `8.8.8.8` after `networksetup` | L1 DNS | Cloudflare WARP running, and DHCP DNS (`Default: DHCP-en0`) overriding the manual setting | quit WARP; per-domain resolver `/etc/resolver/team1.test` |
| `curl: (60) unable to get local issuer certificate` | L5/6 TLS | Mac 4 trusted the **leaf** certificate (`538E…`), not the Root CA | removed it, trusted `Team1 Local Root CA` (`E02B…`) |
| `curl -I` → `HTTP 501` from Backend B | L7 | Python `BaseHTTPRequestHandler` had no `do_HEAD` | added HEAD support |
| nginx warned `duplicate header line: Server` | L7 | Backend B set `Server` twice | set it once via `server_version` |
| Round-robin uneven (`B B A A A B`) | L7 | each nginx worker kept its own counter | `zone backend_cluster 1m;` |
| DNS cutover sent clients to a dead edge | L4/L5 | standby nginx not started (old cert path) | rebuilt the standby config from Mac 2's; health-check before cutover |
| Pushing from the coordinating Mac failed: `Could not resolve host: github.com` | L1 DNS | stale manual DNS servers (`10.7.22.124`, `10.7.1.218`) on that Mac | `networksetup -setdnsservers Wi-Fi Empty` |
| Team IPs changed between sessions | L3 | DHCP + private (rotating) Wi-Fi MAC addresses | `team.env` + `check_ips.sh`; set Private Wi-Fi Address to Fixed |

---

## 4. Learning summary (one paragraph per extension)

**Extension A: Backup DNS resolver.** A **DNS service failure** stops the client before any connection starts: the name does not resolve (`curl: (6) Could not resolve host`). An **application server failure** leaves DNS working, and the client gets a connection error or HTTP 502 from the edge. They need different redundancy: a second name server for DNS, a load balancer with health checks for the application. The pcap shows Mac 1 is still alive (it answers with ICMP "port unreachable"), but nothing listens on port 53, so the resolver moves to the next server.

**Extension B: DNS TTL and controlled record change.** The TTL is how long a client may reuse an answer. The delay a client sees is the **remaining** TTL of its cached entry, so anything between 0 and 30 s (we measured 23 s and 3 s). Before a planned migration, operators lower the TTL in advance. A short TTL means fast cutover but more DNS queries; a long TTL means less load but slow recovery. `dig` bypasses the macOS cache, so to see cache behaviour you must use `dscacheutil -q host` or a real request.

**Extension C: Service isolation.** The edge is the only path to the application, so clients cannot skip TLS, logging or load balancing (least privilege). `block drop` gives a **timeout** (packet silently dropped); a closed port gives **connection refused** (RST). Telling these apart is a quick way to separate a firewall problem from a stopped service. Mac 3 is an MDM-managed Mac: the Application Firewall could not be changed from the command line, but pf still worked.

**Extension D: High-availability failover.** Open-source nginx uses **passive** health checks: it learns a backend is down from real requests failing, retries them on the next server, and stops sending to the failed one for `fail_timeout`. The cost is a slower first request after a failure. **Mac 2's nginx is now the single point of failure**: if it stops, every request fails (Ext F drill D2 shows this). Removing it needs a second edge (we built one in Ext E) plus a way to move traffic automatically: a floating IP with VRRP/keepalived, DNS failover with health checks, or a managed cloud load balancer.

**Extension E: Controlled edge migration.** DNS cutover moves **new lookups**, not open connections. Clients move one by one as their cached answers expire, so the old edge must keep running for at least one TTL. Both DNS servers must be changed together, or clients get different answers depending on which server they ask. The standby must use a certificate the clients already trust, otherwise the cutover appears to users as a TLS error.

**Extension F: Troubleshooting.** Faults rarely show up where they first appear. During the project a "DNS problem" was really a VPN client (Cloudflare WARP) overriding the resolver, and a "TLS problem" was the wrong certificate in the client's trust store. Checking one layer at a time from the client (link/IP, then DNS, then TCP, then TLS, then HTTP) and stopping at the first failure found each cause quickly, and the drills confirmed the pattern: a stopped edge shows up as TCP *connection refused* (L4), while stopped backends show up as HTTP 502 with DNS, TCP and TLS still healthy (L7). Two error words carry most of the information: *refused* means the host is up but nothing listens on the port; *timed out* means packets are dropped by a firewall or the host is unreachable.

**Overall.** Phase 2 showed that each layer needs its own redundancy and its own way of being checked. A backup DNS server protects name resolution, but it does nothing for a dead backend; the load balancer's health checks protect against backend failure, but not against the load balancer itself. DNS-based migration works only within the limits of TTL and caching, so it must be planned (lower the TTL, prepare and test the target, keep the old edge running). Firewall isolation forces all traffic through the edge, and the difference between a timeout and a refused connection tells you which layer is blocking. Most of all, the project showed that a calm, layer-by-layer check beats guessing.

---

## 5. Limitations and notes
- **Mac 4 DNS:** campus DHCP DNS kept overriding the manual Wi-Fi DNS, so Mac 4 resolves `team1.test` through `/etc/resolver/team1.test` (both team DNS servers). Plain `dig` reads `/etc/resolv.conf` and does not use that file; demonstrate with `dscacheutil -q host -a name app.team1.test` or `dig @10.7.5.14 …`.
- **Edge SPOF remains.** Ext E moves traffic manually through DNS; there is no automatic edge failover (no VRRP/floating IP).
- **IPs are DHCP leases.** If they change before the demo: update `team.env`, run `./scripts/check_ips.sh`, fix the listed configs, and update the client resolver file.
- Private keys (`ca.key`, `server.key`) are in the repository because this is a closed lab; a real deployment would keep them in a secret store.
