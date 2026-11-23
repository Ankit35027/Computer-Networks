# Evidence Screenshots – Index

Live terminal screenshots taken on the 4 team Macs (23–24 Nov 2026, campus Wi-Fi 10.7.0.0/19).
Prefix = stage / extension. Matching text logs and pcaps are in each `MAC-X/evidence/` folder.

| File | What it proves |
|---|---|
| **Stage 0 – IP / MAC inventory (Task A)** | |
| S0_01_Mac4_inventory_IP_MAC_DNS | Mac 4 = 10.7.17.220, en0, MAC, gateway 10.7.0.1 |
| S0_02_Mac1_inventory_IP_MAC_DNS | Mac 1 = 10.7.5.14, dnsmasq installed |
| S0_03_Mac3_inventory_IP_MAC | Mac 3 = 10.7.13.57 |
| S0_04_Mac2_inventory_IP_MAC_DNS_nginx | Mac 2 = 10.7.31.100, nginx installed |
| **Stage 1 – services up on new IPs** | |
| S1_01_Mac1_dnsmasq_started_dig_TTL30 | `app.team1.test 30 IN A 10.7.31.100` from Mac 1 DNS |
| S1_02_Mac3_BackendA_started_port3001 | Backend A JSON on :3001 |
| S1_03_Mac2_nginx_started_reaches_BackendA | nginx config OK, edge → 10.7.13.57:3001 succeeded |
| S1_04_Mac4_diag_WARP_overrides_DNS | Troubleshooting finding: Cloudflare WARP / DHCP DNS overriding the client resolver |
| **Phase 1 Task G – protocol flow** | |
| P1_TaskG_Mac4_full_flow_DNS_TCP_TLS_tcpdump | DNS query/response (UDP 53) → TCP SYN/SYN-ACK/ACK (8443) → TLS ClientHello/ServerHello → encrypted data, with ephemeral ports. pcap: `MAC-4/evidence/phase1_final/` |
| **Extension D – HA failover** | |
| ExtD_01_Mac3_BackendA_stopped_234155 | Backend A killed at 23:41:55 |
| ExtD_02_Mac3_BackendA_restarted_234220 | Backend A restarted at 23:42:20 |
| ExtD_03_Mac2_errorlog_connect_refused_and_accesslog | `connect() failed (61: Connection refused)` + `upstream server temporarily disabled` |
| ExtD_04_Mac2_accesslog_failover_and_recovery | `upstream: 10.7.13.57:3001, 10.7.17.220:3002` → served by B (retry), all 200; A/B alternation resumes after restart |
| **Extension A – backup DNS** | |
| ExtA_01_Mac3_backup_dnsmasq_running | Backup dnsmasq on 10.7.13.57:53 answers 10.7.31.100 |
| ExtA_02_Mac2_client_DNS_primary_plus_backup | Client DNS list = 10.7.5.14, 10.7.13.57 |
| ExtA_03_Mac1_client_DNS_primary_plus_backup | Client DNS list = 127.0.0.1, 10.7.13.57 |
| ExtA_04_Mac4_backup_DNS_reachable_5of5 | Backup reachable from client 5/5 |
| ExtA_05_Mac1_primary_restored | Primary dnsmasq restarted after the test |
| ExtA_06_Mac4_failover_primary_down_backup_answers_pcap | Primary timed out → backup answers → HTTPS 200; pcap shows ICMP "udp port 53 unreachable" from Mac 1 then query to Mac 3 |
| **Extension C – service isolation (pf)** | |
| ExtC_00_Mac3_managed_Mac_app_firewall_locked | Mac 3 is MDM-managed: Application Firewall locked (pf still usable) |
| ExtC_01_Mac1_BEFORE_backends_directly_reachable | Before: client reaches 3001 and 3002 directly |
| ExtC_02_Mac3_pf_enabled_port3001 | Anchor `com.apple/cn-isolation`: pass edge + standby + lo0, block drop rest (3001) |
| ExtC_03_Mac4_pf_enabled_port3002 | Same for 3002 |
| ExtC_04_Mac2_edge_still_allowed | Edge (Mac 2) still reaches both backends |
| ExtC_05_Mac3_rollback_pf_restored | `pf_isolation.sh disable`: anchor flushed, pf back to original (Disabled) state |
| ExtC_06_Mac4_rollback_pf_restored | Same on Mac 4 |
| ExtC_07_Mac1_AFTER_ROLLBACK_reachable_again | After rollback the client reaches 3001/3002 again (rollback proven) |
| **Extension B – TTL** | |
| ExtB_01_Mac4_TTL_cache_lag_23s_run1 | Record changed on DNS server at 00:25:50; client cache kept the OLD IP until 00:26:09 and switched at 00:26:13 (~23 s ≤ TTL 30 s). In this run the standby edge was not running, so `served-by=NONE` after cutover (see ExtF lesson) |
| **Troubleshooting findings (Ext F)** | |
| ExtF_lesson_01_Mac3_standby_not_ready_cert_path | Standby nginx failed to start (wrong cert path in old config) → cutting DNS over to a not-ready edge caused an outage for cached-out clients. Lesson: health-check the target before a DNS cutover |
