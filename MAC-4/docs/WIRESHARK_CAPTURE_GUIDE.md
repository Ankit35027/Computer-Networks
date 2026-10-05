# Wireshark Capture Guide for Mac 4 (Phase 1)

This guide details the exact steps, capture filters, and packet evidence to collect on **Mac 4** for **Task G**.

Because Mac 4 is both a **Test Client** and **Backend Server B**, you have two perspectives to showcase to the evaluator!

---

## Perspective 1: Mac 4 as Test Client

Capture Interface: `en0` (Wi-Fi)

### 1. Capture Sequence
1. Open Wireshark and select interface `en0`.
2. Clear system DNS cache:
   ```bash
   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
   ```
3. In Wireshark, set display filter:
   ```text
   dns || (tcp.port == 443)
   ```
4. Start packet capture.
5. In your terminal, run:
   ```bash
   curl https://app.team1.test/api/status
   ```
6. Stop capture and save as `mac4_client_protocol_flow.pcapng`.

---

### 2. Packets to Identify & Explain

#### A. DNS Query and Response (Application Layer over UDP 53)
- **Display Filter**: `dns`
- **What to show**:
  - **Query packet**:
    - Source IP: `10.7.12.61` (Mac 4)
    - Destination IP: `<Mac 1 IP>` (DNS Server)
    - Source Port: Ephemeral (e.g., `54321`)
    - Destination Port: `53` (UDP)
    - Query: `Standard query 0x... A app.team1.test`
  - **Response packet**:
    - Flags: `Standard query response, No error`
    - Answers: `app.team1.test: type A, class IN, addr <Mac 2 IP>`

#### B. TCP Three-Way Handshake (Transport Layer)
- **Display Filter**: `tcp.port == 443 and ip.addr == <Mac 2 IP>`
- **What to show**:
  - **Packet 1 (SYN)**:
    - Flags: `[SYN]` (0x002)
    - Client Seq = `0` (Relative)
    - Window Size, MSS, SACK Permitted options.
    - Ephemeral client port -> Server port `443`.
  - **Packet 2 (SYN-ACK)**:
    - From Mac 2 to Mac 4.
    - Flags: `[SYN, ACK]` (0x012)
    - Server Seq = `0`, Ack = `1` (SYN consumes 1 sequence number).
  - **Packet 3 (ACK)**:
    - From Mac 4 to Mac 2.
    - Flags: `[ACK]` (0x010)
    - Seq = `1`, Ack = `1`.
    - Handshake complete! Socket pair established.

#### C. TLS Handshake (Session / Security Layer)
- **Display Filter**: `tls or ssl`
- **What to show**:
  - **Client Hello**: TLS Version, Client Random, Cipher Suites offered, SNI extension (`app.team1.test`).
  - **Server Hello**: Selected Cipher Suite (e.g., `TLS_AES_256_GCM_SHA384`), Server Random.
  - **Certificate**: Team's Certificate provided by Mac 2.
  - **Server Key Exchange / Finished**: Key agreement (ECDH) and encrypted handshake message.
  - **Application Data**: Show that subsequent HTTP requests/responses are completely encrypted (hex payload cannot be read).

---

## Perspective 2: Mac 4 as Backend Server B

Capture Interface: `en0` or `lo0` (if tested locally)

### 1. Capture Filter
```text
tcp.port == 3002
```

### 2. What to Observe & Explain
1. **TCP Handshake between Mac 2 (Edge) and Mac 4 (Backend B)**:
   - Source IP is Mac 2 (Edge Nginx), Destination IP is Mac 4 (`10.7.12.61`).
   - Destination Port is `3002`.
2. **Unencrypted HTTP Request**:
   - Unlike the client side (which was encrypted TLS on port 443), the connection between Nginx and Backend B is plain HTTP!
   - HTTP GET `/api/status`.
   - Headers added by Nginx: `X-Forwarded-For`, `X-Real-IP`, `Host`.
3. **HTTP Response from Backend B**:
   - Status: `HTTP/1.1 200 OK`.
   - Header: `X-Backend: B`.
   - Body: `{ "backend": "B", "status": "ok", ... }`.

### 3. Key Viva Concept (TLS Termination):
> "Why does Wireshark show encrypted data between Mac 4 (as client) and Mac 2 (Edge), but plaintext HTTP between Mac 2 and Mac 4 (Backend B)?"
>
> **Answer**: Nginx performs **TLS Termination**. Nginx handles the heavy cryptographic handshake and decrypts client traffic at the edge. Internal communication within the private LAN to the backends is handled via lightweight HTTP.

---

## Perspective 3: HTTP Caching (Task F)

### Capture Filter
```text
http
```
1. Filter on Backend B traffic:
   - First request returns:
     - `HTTP/1.1 200 OK`
     - `Cache-Control: public, max-age=60`
     - `ETag: "backend-b-v1.0"`
   - Second request from client sends:
     - `If-None-Match: "backend-b-v1.0"`
   - Backend B response returns:
     - `HTTP/1.1 304 Not Modified`
     - Content-Length: 0 (No body transferred!)
