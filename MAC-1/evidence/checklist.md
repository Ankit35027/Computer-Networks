# Phase 1 Evidence Checklist — Mac 1
## Computer Networks Course Project

> Check off each item before the Phase 1 review. The evaluator will ask to see every item below.

---

## Task A — LAN Setup

- [ ] Mac 1 private IPv4 address recorded
- [ ] Mac 1 subnet mask / prefix recorded
- [ ] Mac 1 default gateway recorded
- [ ] Mac 1 active interface name recorded (`en0`)
- [ ] Mac 1 MAC address recorded
- [ ] `ping` screenshot: Mac 1 → Mac 2 (3 replies received)
- [ ] `ping` screenshot: Mac 1 → Mac 3 (3 replies received)
- [ ] `ping` screenshot: Mac 1 → Mac 4 (3 replies received)
- [ ] Network topology diagram saved (draw.io / hand-drawn photo)

---

## Task B — Private DNS Server

- [ ] `dnsmasq.conf` deployed with correct Mac 2 IP (no placeholder)
- [ ] `dnsmasq` running — `sudo brew services list` shows `started`
- [ ] `dig @127.0.0.1 app.team1.test` returns Mac 2's IP
- [ ] `dig @127.0.0.1 api.team1.test` returns Mac 2's IP
- [ ] `nslookup app.team1.test 127.0.0.1` returns Mac 2's IP
- [ ] At least 2 other Macs have Mac 1's IP set as their DNS server
- [ ] dnsmasq query log shows incoming queries (tail the log file)

---

## Task G — Protocol Flow Evidence

### DNS Evidence
- [ ] `dig` full output screenshot (showing ANSWER SECTION, TTL, query time)
- [ ] Wireshark capture: DNS query packet from client → Mac 1 port 53 (UDP)
- [ ] Wireshark capture: DNS response packet from Mac 1 → client with Mac 2 IP

### TCP Handshake Evidence
- [ ] Wireshark: SYN packet (client → Mac 2 port 443/8443)
- [ ] Wireshark: SYN-ACK packet (Mac 2 → client)
- [ ] Wireshark: ACK packet (client → Mac 2)
- [ ] Source ephemeral port noted (e.g., 52341)
- [ ] Destination port noted (443 or 8443)

### TLS Handshake Evidence
- [ ] Wireshark: ClientHello packet
- [ ] Wireshark: ServerHello packet
- [ ] Wireshark: Certificate packet (from Mac 2)
- [ ] Wireshark: ChangeCipherSpec / Finished
- [ ] curl `-v` output showing TLS version and cipher suite

### HTTP Headers Evidence
- [ ] `curl -v` output showing request headers and response headers
- [ ] `X-Backend: A` visible in at least one response
- [ ] `X-Backend: B` visible in at least one response
- [ ] `Cache-Control` header visible in response

### Load Balancing Evidence
- [ ] 6 repeated `curl` responses showing alternating X-Backend: A and B

### Port Identification Evidence
- [ ] Port 53/UDP identified as DNS
- [ ] Port 443/TCP (or 8443) identified as HTTPS
- [ ] Client ephemeral port identified (>49152)

---

## Failure Demonstrations (Required)

- [ ] **Wrong DNS** — Changed DNS on a client to wrong IP → `dig` fails, but `ping <MAC2_IP>` still works
- [ ] **Wrong DNS record** — Changed `dnsmasq.conf` to wrong IP → DNS resolves, but HTTPS fails
- [ ] **One backend stopped** — Mac 3 down → requests still flow through Backend B only
- [ ] **Both backends stopped** — Mac 3 + Mac 4 down → nginx returns `502 Bad Gateway`
- [ ] **Wrong port** — `curl https://app.team1.test:9999` → TCP connection refused

---

## Files to Have Ready During Review

| File | Contents |
|------|---------|
| `dns/dnsmasq.conf` | Running DNS config |
| `evidence/dns_query_*.txt` | dig/nslookup output |
| `evidence/curl_verbose_*.txt` | curl -v TLS/HTTP output |
| `evidence/load_balance_*.txt` | X-Backend alternating evidence |
| `evidence/wireshark_capture_*.pcapng` | Wireshark capture file |
| `evidence/dnsmasq_log_*.txt` | DNS query log |
| Topology diagram | Network diagram with IPs and roles |
