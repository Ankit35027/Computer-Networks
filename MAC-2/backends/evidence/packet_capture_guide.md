# Task G - Packet Analysis & Protocol Flow Guide

This document provides exact step-by-step instructions and packet inspection filters for **Wireshark** and **tcpdump** to gather packet capture evidence for **Phase 1 Task G** on **Mac 2 (Edge Reverse Proxy & Load Balancer)**.

---

## 1. Quick Capture Command (tcpdump)

To capture all network traffic for DNS, TCP, and HTTPS on Mac 2:

```bash
# Capture traffic on active interface (e.g., en0 or lo0)
sudo tcpdump -i any -w phase1_capture.pcap 'port 53 or port 8443 or port 443 or port 3001 or port 3002'
```

Perform client requests using `curl` while tcpdump is running:
```bash
curl --cacert certs/ca.crt --connect-to app.team1.test:8443:127.0.0.1:8443 https://app.team1.test:8443/api/status
```

Stop the capture (`Ctrl + C`) and open `phase1_capture.pcap` in **Wireshark**.

---

## 2. Wireshark Display Filters & Layer Inspection

### A. Layer 7 - Private DNS Query & Response
- **Wireshark Filter**: `dns` or `udp.port == 53`
- **What to Observe**:
  - Client sends **DNS Standard Query A `app.team1.test`** (UDP src port: Ephemeral e.g., 51234, dst port: 53).
  - DNS Server (Mac 1) replies with **DNS Standard Query Response A `<Mac 2 Private IP>`**.

### B. Layer 4 - TCP Three-Way Handshake
- **Wireshark Filter**: `tcp.flags.syn == 1 or (tcp.flags.ack == 1 and tcp.len == 0)`
- **What to Observe**:
  1. `SYN`: Client -> Mac 2 (Port 8443 / 443).
  2. `SYN-ACK`: Mac 2 -> Client (Port 8443 / 443).
  3. `ACK`: Client -> Mac 2 (Completes 3-way handshake).
  - Note down the **Client Ephemeral Port** (e.g., 54321) and **Server Well-Known Port** (8443 / 443).

### C. Layer 6/5 - TLS 1.2 / TLS 1.3 Handshake
- **Wireshark Filter**: `tls` or `ssl`
- **What to Observe**:
  1. `Client Hello`: Client sends TLS version preferences, cipher suites, SNI (`app.team1.test`).
  2. `Server Hello`: Mac 2 selects cipher suite (`TLS_AES_128_GCM_SHA256` or `ECDHE-RSA-AES128-GCM-SHA256`).
  3. `Certificate`: Mac 2 sends server certificate (`server.crt`).
  4. `Key Exchange / Change Cipher Spec`: Secure symmetric key negotiated.
  5. `Application Data`: All HTTP request/response payloads are now fully encrypted!

### D. Layer 7 - HTTP Headers & Load Balancing Trace
- **Wireshark Filter**: `http` or `tcp.port == 3001 or tcp.port == 3002`
- **What to Observe**:
  - Edge Nginx forwards request to Backend A (`127.0.0.1:3001` or Mac 3) and Backend B (`127.0.0.1:3002` or Mac 4).
  - Inspect HTTP Response Header: `X-Backend: A` on first request, `X-Backend: B` on second request.

---

## 3. Protocol Layer Mapping Summary Table

| Protocol Layer | Layer Name | Protocol / Event | Source Port | Destination Port | Key Identifiers |
|----------------|------------|------------------|-------------|------------------|-----------------|
| Layer 7 | Application | DNS Query/Resp | Ephemeral (51234) | 53 (UDP) | Domain `app.team1.test` -> Mac 2 IP |
| Layer 4 | Transport | TCP 3-Way Handshake | Ephemeral (54321) | 8443 / 443 (TCP) | `SYN`, `SYN-ACK`, `ACK` |
| Layer 5/6 | Session/Presentation | TLS Handshake | Ephemeral (54321) | 8443 / 443 (TCP) | `ClientHello`, `ServerHello`, `Certificate` |
| Layer 7 | Application | HTTP/1.1 or HTTP/2 | Ephemeral (54321) | 8443 / 443 | `GET /api/status`, `X-Backend: A/B` |
| Upstream Proxy | Application | Proxy Pass to Backend | Ephemeral | 3001 / 3002 | Nginx -> Backend A / B |
