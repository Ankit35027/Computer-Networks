# Architecture Document — Private Network Service Platform
## Computer Networks Course Project (Phase 1 & Phase 2)
### Team 1 Architecture & Network Topology

---

## 1. Network Inventory & Machine Roles

| Machine | Role | Hostname / User | LAN IPv4 | Bound Ports | Service / Process | Cloud Equivalent |
|---|---|---|---|---|---|---|
| **Mac 1** | Primary DNS Server + Test Client | `ankitnst35027` | `10.7.21.249` | `53/UDP`, `53/TCP` | `dnsmasq` v2.90 | AWS Route 53 / CoreDNS |
| **Mac 2** | Edge Reverse Proxy & Load Balancer | `kchhillar13` | `10.7.23.158` | `8443/TCP`, `80/TCP` | `nginx` v1.31.6 + TLS 1.3 | AWS ALB / Cloudflare Edge |
| **Mac 3** | Backend Server A | `Kinshu` | `10.7.22.2` | `3001/TCP` | Node.js REST API | EC2 Instance A |
| **Mac 4** | Backend Server B + Secondary Client | Team Member | `10.7.21.68` | `3002/TCP` | Python / Node.js REST API | EC2 Instance B |

- **Subnet Prefix**: `10.7.0.0/19` (Netmask: `255.255.224.0`)
- **Default Gateway / Router**: `10.7.0.1`
- **Private Domain**: `app.team1.test`, `api.team1.test`, `team1.test`
- **Active Network Interface**: `en0` (Wi-Fi)

---

## 2. Physical & Logical Network Topology

```mermaid
graph TD
    subgraph LAN ["Campus Private LAN Subnet (10.7.0.0/19)"]
        Router["Wi-Fi Gateway / Router<br/>10.7.0.1"]

        Mac1["Mac 1 (DNS Primary)<br/>10.7.21.249<br/>Port 53 (dnsmasq)"]
        Mac2["Mac 2 (Edge Proxy & LB)<br/>10.7.23.158<br/>Port 8443 (nginx + TLS)"]
        Mac3["Mac 3 (Backend A)<br/>10.7.22.2<br/>Port 3001 (HTTP REST)"]
        Mac4["Mac 4 (Backend B)<br/>10.7.21.68<br/>Port 3002 (HTTP REST)"]

        Router --- Mac1
        Router --- Mac2
        Router --- Mac3
        Router --- Mac4
    end

    Mac1 -.->|"1. Resolve app.team1.test"| Mac2
    Mac2 ==>|"Round Robin Upstream"| Mac3
    Mac2 ==>|"Round Robin Upstream"| Mac4
```

---

## 3. End-to-End Protocol Request Flow

When a client requests `https://app.team1.test:8443/api/status`:

```mermaid
sequenceDiagram
    autonumber
    actor Client as Client (Mac 1 or Mac 4)
    participant DNS as Primary DNS Server (Mac 1 :53)
    participant Edge as Edge Reverse Proxy (Mac 2 :8443)
    participant B_A as Backend A (Mac 3 :3001)
    participant B_B as Backend B (Mac 4 :3002)

    Note over Client,DNS: Phase 1: DNS Resolution (UDP 53)
    Client->>DNS: Standard query A app.team1.test (Frame 810)
    DNS-->>Client: Standard query response: 10.7.23.158 (TTL 30s) (Frame 811)

    Note over Client,Edge: Phase 2: TCP 3-Way Handshake (TCP 8443)
    Client->>Edge: [SYN] (Src Port: Ephemeral 58051, Dst Port: 8443)
    Edge-->>Client: [SYN, ACK] (Src Port: 8443, Dst Port: 58051)
    Client->>Edge: [ACK] (Handshake Complete)

    Note over Client,Edge: Phase 3: TLS 1.3 Handshake (Encrypted Session)
    Client->>Edge: Client Hello (SNI = app.team1.test)
    Edge-->>Client: Server Hello, Certificate (CN=app.team1.test), Change Cipher Spec
    Client->>Edge: Finished / Key Exchange
    Edge-->>Client: Finished

    Note over Client,B_B: Phase 4: HTTP Request & Upstream Load Balancing
    Client->>Edge: GET /api/status (Encrypted TLS Application Data)
    alt Odd Request (Round-Robin 1, 3, 5)
        Edge->>B_B: Forward HTTP GET to 10.7.21.68:3002
        B_B-->>Edge: HTTP 200 OK {"status":"ok","backend":"B"} (X-Backend: B)
    else Even Request (Round-Robin 2, 4, 6)
        Edge->>B_A: Forward HTTP GET to 10.7.22.2:3001
        B_A-->>Edge: HTTP 200 OK {"status":"ok","backend":"A"} (X-Backend: A)
    end
    Edge-->>Client: HTTP/2 200 OK (Encrypted Application Data Response)
```

---

## 4. OSI & TCP/IP Layer Mapping

| Layer (OSI) | Protocol | Role in Project | Verification Tool & Evidence |
|---|---|---|---|
| **Application (L7)** | DNS, HTTP/2, REST | Resolves domain, handles JSON API requests | `dig`, `curl -kv`, `tail /tmp/dnsmasq_primary.log` |
| **Presentation (L6)** | TLS 1.3 | Encrypts payload, verifies X.509 server certificate | OpenSSL, Wireshark `tls.handshake` filter |
| **Session (L5)** | TLS Session | Maintains secure session keys & SNI handshake | Wireshark Frame `Client Hello (SNI=app.team1.test)` |
| **Transport (L4)** | TCP / UDP | UDP 53 for DNS; TCP 8443 for HTTPS; TCP 3001/3002 for upstream | Wireshark `tcp.flags.syn == 1`, ephemeral ports |
| **Network (L3)** | IPv4, ICMP | Routes packets across `10.7.0.0/19` subnet | `ping -c 3`, `netstat -rn -f inet` |
| **Data Link (L2)** | Ethernet / 802.11 | MAC address framing on `en0` Wi-Fi adapter | `ifconfig en0`, Wireshark Ethernet frames |
| **Physical (L1)** | Wi-Fi / Radio | Physical wireless signal communication | Campus Access Point connection |

---

## 5. Security & Isolation Model

- **Internal Domain Only**: `.test` reserved TLD prevents external DNS collision and avoids macOS `.local` mDNS conflicts.
- **TLS Termination**: All client-facing traffic is secured via TLS 1.3 with AES-GCM / ChaCha20-Poly1305 ciphers.
- **Backend Protection**: Backends (Mac 3 and Mac 4) are abstract application workers; clients only communicate with the Edge IP (`10.7.23.158`).
