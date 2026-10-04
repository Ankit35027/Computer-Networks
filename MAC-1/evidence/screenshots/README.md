# Evidence Screenshots Directory — Mac 1

Save all your evaluation screenshots in this directory with the standardized names below.
This matches the Review 1 checklist and makes each proof findable in under 10 seconds.

| File Name | Section | Description |
|---|---|---|
| `SS01_Mac1_Network_Inventory.png` | Task A | Mac 1 IP (`10.7.21.249`), Subnet Mask, Gateway, MAC address |
| `SS02_LAN_Ping_All_Macs.png` | Task A | Ping test to Mac 2 (`10.7.23.158`), Mac 3 (`10.7.22.2`), Mac 4 (`10.7.21.68`) with 0% packet loss |
| `SS03_DNS_Port53_Listening.png` | Task B | `sudo lsof -i :53 -nP` showing dnsmasq listening on UDP/TCP port 53 |
| `SS04_DNS_Config_dnsmasq.png` | Task B | `cat configs/dnsmasq.conf` showing domain mapping to Edge IP |
| `SS05_DNS_Dig_Resolution.png` | Task B | `dig @127.0.0.1 app.team1.test` showing ANSWER `10.7.23.158` & TTL 30 |
| `SS06_DNS_nslookup_QueryLog.png` | Task B | `nslookup` output + `/tmp/dnsmasq_primary.log` showing incoming queries from Mac 3 |
| `SS07_TLS_Handshake_HTTP2.png` | Task E | `curl -kv` verbose output showing TLS 1.3, Server Certificate, and HTTP/2 |
| `SS08_RoundRobin_LoadBalancing.png` | Task D | 6 continuous requests alternating between Backend A (3001) & Backend B (3002) |
| `SS09_Wireshark_DNS_Query_Response.png` | Task G | Wireshark packet capture showing Frame 810/811 (query & response for `app.team1.test`) |
| `SS10_Wireshark_TCP_3Way_Handshake.png` | Task G | Wireshark showing `[SYN]` from ephemeral port & `[SYN, ACK]` from port 8443 |
| `SS11_Wireshark_TLS_ClientServer_Hello.png` | Task G | Wireshark showing `Client Hello (SNI=app.team1.test)` & `Server Hello` |
| `SS12_Wireshark_Encrypted_Application_Data.png` | Task G | Wireshark showing encrypted TLS Application Data payload |
| `SS13_Failure1_Wrong_DNS_Server.png` | Section 6.3 | `dig @1.2.3.4` timing out while direct IP ping succeeds |
| `SS14_Failure2_Wrong_Port.png` | Section 6.3 | `curl https://app.team1.test:9999` returning Connection Refused |
