# Master Architecture Document — Computer Networks Course Project
## Private Network Service Platform (Team 1 — Phase 1 & Phase 2)

---

## 1. System Overview & Machine Inventory Table

| Machine Folder | Hardware Role | LAN IPv4 | Bound Ports | Core Software | Cloud Equivalent |
|---|---|---|---|---|---|
| **`MAC-1`** | Primary DNS Server & Client | `10.7.21.249` | `53/UDP`, `53/TCP` | `dnsmasq` v2.90, `dig`, `curl` | AWS Route 53 / CoreDNS |
| **`MAC-2`** | Edge Reverse Proxy & Load Balancer | `10.7.23.158` | `8443/TCP`, `80/TCP` | `nginx` v1.31.6 + TLS 1.3 | AWS ALB / Cloudflare Edge |
| **`MAC-3`** | Backend Application Server A | `10.7.22.2` | `3001/TCP` | Node.js REST API (`server.js`) | AWS EC2 / Worker A |
| **`MAC-4`** | Backend Server B + Test Client | `10.7.21.68` | `3002/TCP` | Node / Python REST API (`server.js`) | AWS EC2 / Worker B |

- **Subnet Range**: `10.7.0.0/19` (Netmask: `255.255.224.0`)
- **Default Gateway**: `10.7.0.1`
- **Private Domain Namespace**: `app.team1.test`, `api.team1.test`, `team1.test`

---

## 2. End-to-End Network Topology

```mermaid
flowchart TD
    subgraph LAN ["Campus Private LAN Subnet (10.7.0.0/19)"]
        Router["Wi-Fi Gateway / Router<br/>10.7.0.1"]

        Mac1["MAC-1: Primary DNS Server<br/>10.7.21.249<br/>Port 53 (dnsmasq)"]
        Mac2["MAC-2: Edge Proxy & LB<br/>10.7.23.158<br/>Port 8443 (nginx + TLS)"]
        Mac3["MAC-3: Backend Server A<br/>10.7.22.2<br/>Port 3001 (Node.js)"]
        Mac4["MAC-4: Backend Server B<br/>10.7.21.68<br/>Port 3002 (Node/Python)"]

        Router --- Mac1
        Router --- Mac2
        Router --- Mac3
        Router --- Mac4
    end

    Mac1 -.->|"1. DNS Query (app.team1.test)"| Mac1
    Mac1 -- "2. HTTPS Request (TLS 8443)" --> Mac2
    Mac4 -- "HTTPS Request (TLS 8443)" --> Mac2
    
    Mac2 ==>|"3a. Round-Robin Proxy Pass (3001)"| Mac3
    Mac2 ==>|"3b. Round-Robin Proxy Pass (3002)"| Mac4
```

---

## 3. Protocol Request Flow (Sequence & Packet Evidence)

```mermaid
sequenceDiagram
    autonumber
    actor Client as Client (MAC-1 / MAC-4)
    participant DNS as Primary DNS Server (MAC-1 :53)
    participant Edge as Edge Proxy & LB (MAC-2 :8443)
    participant B_A as Backend A (MAC-3 :3001)
    participant B_B as Backend B (MAC-4 :3002)

    Note over Client,DNS: Phase 1: DNS Resolution (UDP 53)
    Client->>DNS: Standard query A app.team1.test
    DNS-->>Client: Standard query response: 10.7.23.158 (TTL 30s)

    Note over Client,Edge: Phase 2: TCP 3-Way Handshake (TCP 8443)
    Client->>Edge: [SYN] (Src Ephemeral Port: >49152, Dst Port: 8443)
    Edge-->>Client: [SYN, ACK]
    Client->>Edge: [ACK]

    Note over Client,Edge: Phase 3: TLS 1.3 Handshake (Encryption)
    Client->>Edge: Client Hello (SNI = app.team1.test)
    Edge-->>Client: Server Hello, Certificate (CN=app.team1.test)
    Client->>Edge: Finished / Key Exchange
    Edge-->>Client: Finished

    Note over Client,B_B: Phase 4: HTTP Request & Load Balancing
    Client->>Edge: GET /api/status (TLS Application Data)
    alt Request #1, #3, #5 (Round-Robin)
        Edge->>B_B: Forward HTTP GET to 10.7.21.68:3002
        B_B-->>Edge: HTTP 200 OK {"backend":"B"} (X-Backend: B)
    else Request #2, #4, #6 (Round-Robin)
        Edge->>B_A: Forward HTTP GET to 10.7.22.2:3001
        B_A-->>Edge: HTTP 200 OK {"backend":"A"} (X-Backend: A)
    end
    Edge-->>Client: HTTP/2 200 OK (Encrypted Application Data Response)
```

---

## 4. OSI & TCP/IP Layer Mapping

| Layer # | OSI Layer Name | TCP/IP Layer Name | Protocol / Component in Project | Evidence Verification |
|---|---|---|---|---|
| **7** | Application | Application | DNS (`dnsmasq`), HTTP/1.1, HTTP/2, REST APIs | `dig`, `curl -kv`, query logs |
| **6** | Presentation | Application / TLS | TLS 1.3 (OpenSSL, Nginx cert termination) | Certificate `CN=app.team1.test` |
| **5** | Session | Application / TLS | TLS Session Keys & Connection Management | Wireshark `Client Hello (SNI)` |
| **4** | Transport | Transport | TCP (8443, 3001, 3002), UDP (53) | Wireshark `tcp.flags.syn == 1` |
| **3** | Network | Internet | IPv4 Packets, Subnet Routing (`10.7.0.0/19`) | `ping -c 3`, `netstat -rn` |
| **2** | Data Link | Network Access | Ethernet / Wi-Fi Frames (MAC Addresses) | `ifconfig en0`, Wireshark Frames |
| **1** | Physical | Network Access | Wi-Fi Signal / Physical Radio Transmission | Physical Campus AP |
