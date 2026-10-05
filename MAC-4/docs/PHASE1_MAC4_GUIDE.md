# Phase 1 Guide: Mac 4 (Backend Server B + Test Client)

## 1. Machine Identity & Role Overview

| Attribute | Value |
| :--- | :--- |
| **Machine Role** | **Mac 4: Backend Server B + Test Client** |
| **Primary Services** | HTTP/REST Application (`backend/server.js`), curl / browser, Wireshark |
| **What It Represents** | Application Server Instance B & Client Consumer |
| **Listening Port** | TCP `3002` (must listen on `0.0.0.0`, not `127.0.0.1`) |
| **Response Header** | `X-Backend: B` |
| **Active Network Interface** | `en0` (Wi-Fi) |
| **IPv4 Address** | `10.7.12.61` |
| **Subnet Mask** | `255.255.224.0` (`/19`) |
| **Default Gateway** | `10.7.0.1` |
| **MAC Address** | `5a:c0:8d:53:fb:50` |

---

## 2. Request Flow Across Architecture

```text
[ Test Client: Mac 4 ]
        │
        ▼ (1) DNS Query (UDP port 53)
[ Mac 1: Private DNS (dnsmasq) ] ──> Returns Mac 2 IP (Edge)
        │
        ▼ (2) HTTPS Request (TCP port 443 + TLS Handshake)
[ Mac 2: Nginx Reverse Proxy / Load Balancer ]
        │
        ├──────────────────────┬──────────────────────┐
        │ Round-robin          │ Round-robin          │
        ▼                      ▼                      ▼
[ Mac 3: Backend A ]   [ Mac 4: Backend B ]    [ Alternates ]
   (Port 3001)            (Port 3002)
   X-Backend: A           X-Backend: B
```

---

## 3. Step-by-Step Task Execution

### Task A: Establish the Private LAN
1. Verify network inventory parameters:
   ```bash
   ./network/mac4_network_info.sh
   ```
2. Update teammate IPs in `network/team_ips.env`:
   - `MAC1_DNS_IP`: IP of Mac 1 (DNS Server)
   - `MAC2_EDGE_IP`: IP of Mac 2 (Edge Nginx)
   - `MAC3_BACKEND_A_IP`: IP of Mac 3 (Backend A)
   - `TEAM_DOMAIN`: e.g. `app.team1.test`
3. Test connectivity across all team Macs:
   ```bash
   ./network/ping_team.sh
   ```

### Task B: Configure Private DNS Resolver on Mac 4
Mac 4 functions as a test client, so its DNS resolver must point to Mac 1:
1. Run the interactive DNS configuration script:
   ```bash
   ./client/setup_dns.sh
   ```
   Select Option 1 (or enter Mac 1's IP).
   *(Alternatively in macOS GUI: System Settings -> Network -> Wi-Fi -> Details -> DNS -> Add Mac 1's IP).*
2. Verify resolution:
   ```bash
   ./client/test_dns.sh
   ```
   Confirm that `app.teamX.test` returns Mac 2's IP address.

### Task C: Run Backend Server B
Mac 4 must run Backend B on port 3002:
1. Start Backend B:
   ```bash
   ./backend/start_backend.sh
   ```
   It binds to `0.0.0.0:3002` so Mac 2 (Edge) can reach it across the LAN.
2. Verify local endpoints in a separate terminal:
   ```bash
   ./backend/test_backend_local.sh
   ```
   Verified Endpoints:
   - `GET /` -> Status 200 JSON, `X-Backend: B`
   - `GET /api/status` -> Status 200 `{ "backend": "B", "status": "ok" }`
   - `GET /api/cached` -> Status 200 with `Cache-Control: public, max-age=60` and `ETag`
   - `GET /api/cached` with `If-None-Match` -> Status `304 Not Modified`

### Task D: Verify Load Balancing (via Mac 2 Edge)
Mac 2's Nginx proxies traffic between Mac 3 (port 3001) and Mac 4 (port 3002).
From Mac 4 (as test client):
```bash
./client/test_load_balancing.sh
```
Sends 10 requests to `https://app.teamX.test/api/status` and confirms that `X-Backend: A` and `X-Backend: B` alternate evenly.

### Task E: Trust Team CA & HTTPS Testing
To test over HTTPS without `-k` (insecure mode):
1. Obtain the team root CA certificate from Mac 2 (`rootCA.crt`).
2. Install and trust it in macOS Keychain:
   ```bash
   ./client/install_ca_cert.sh path/to/rootCA.crt
   ```
3. Test HTTPS connectivity:
   ```bash
   ./client/test_https.sh
   ```

### Task F: HTTP Caching Demonstration
Run the automated caching test:
```bash
./client/test_caching.sh
```
- First request: Returns `HTTP 200 OK`, `Cache-Control: max-age=60`, and `ETag: "backend-b-v1.0"`.
- Second request: Sends `If-None-Match: "backend-b-v1.0"`, returns `HTTP 304 Not Modified`.

### Task G: Wireshark Captures
See [WIRESHARK_CAPTURE_GUIDE.md](file:///Users/anshikaseth/Desktop/computer%20network/docs/WIRESHARK_CAPTURE_GUIDE.md) for step-by-step packet capture filters and screenshots.

---

## 4. Phase 1 Required Failure Demonstrations

Run the interactive failure tester:
```bash
./client/test_failure_scenarios.sh
```
1. **Wrong DNS server configured**: Lookups fail while direct IP ping still works (proves DNS and IP are independent).
2. **DNS record points to wrong IP**: Lookup succeeds, but connection times out / fails (proves DNS is only a directory).
3. **One backend is stopped**: Stop Backend B (`kill -9 $(lsof -ti :3002)`); edge routes 100% to Backend A.
4. **Both backends stopped**: Returns `502 Bad Gateway` from Nginx (proves boundary between edge and upstream).
5. **Wrong destination port**: Connection refused (TCP RST packet) (proves L3 IP and L4 Port separation).
