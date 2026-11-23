# Master Architecture Document — Computer Networks Course Project
## Private Network Service Platform (Team 1 — Phase 1 & Phase 2 Architecture)

---

## 1. System Overview & Machine Inventory Table

The system is deployed locally on a dedicated private LAN subnet (`10.7.0.0/19`), featuring full DNS resolution, TLS 1.3 termination, HTTP/2 multiplexing, active load balancing, HTTP caching, service isolation, automated failover, and fault diagnosability.

| Machine Directory | LAN IPv4 | Bound Ports | Phase 1 Role | Phase 2 Extensions | Cloud Equivalent |
|---|---|---|---|---|---|
| **[`MAC-1/`](MAC-1/)** | `10.7.21.249` | `53/UDP`, `53/TCP` | Primary Authoritative & Recursive DNS Resolver | Primary DNS Service Lifecycle Controller | AWS Route 53 / CoreDNS |
| **[`MAC-2/`](MAC-2/)** | `10.7.23.158` | `8443/TCP`, `80/TCP` | Edge Reverse Proxy & Upstream Load Balancer (TLS 1.3) | Nginx HA Passive Health Checking & Ejection | AWS Application Load Balancer |
| **[`MAC-3/`](MAC-3/)** | `10.7.22.2` | `3001/TCP`, `53/UDP`, `8443/TCP` | Upstream Application Backend Server A | **Ext A**: Backup DNS<br/>**Ext C**: PF Service Isolation<br/>**Ext E**: Standby Edge Gateway | AWS EC2 Node + Standby Load Balancer |
| **[`MAC-4/`](MAC-4/)** | `10.7.21.68` | `3002/TCP` | Upstream Application Backend Server B + Test Client | **Ext C**: PF Service Isolation<br/>Primary Evaluation Client Node | AWS EC2 Node + Client Workstation |

- **Subnet Range**: `10.7.0.0/19` (Netmask: `255.255.224.0`)
- **Default Gateway**: `10.7.0.1`
- **Private Domain Namespace**: `app.team1.test`, `api.team1.test`, `team1.test`
- **DNS Record TTL**: `30 seconds` (`local-ttl=30`)

---

## 2. Comprehensive Network Topology Diagram

```mermaid
flowchart TD
    subgraph LAN ["Campus Private LAN Subnet (10.7.0.0/19)"]
        Router["LAN Gateway / Router<br/>10.7.0.1"]

        subgraph M1 ["MAC-1 (10.7.21.249)"]
            DNS1["Primary DNS Resolver<br/>dnsmasq (Port 53 UDP/TCP)<br/>TTL: 30s"]
        end

        subgraph M2 ["MAC-2 (10.7.23.158)"]
            EdgeProxy["Edge Reverse Proxy & Load Balancer<br/>Nginx 1.31.6 (Port 8443 TLS 1.3)<br/>Passive Health Checking (max_fails=1)"]
        end

        subgraph M3 ["MAC-3 (10.7.22.2)"]
            DNS2["Extension A: Backup DNS Resolver<br/>dnsmasq (Port 53)"]
            PF3["Extension C: PF Firewall<br/>(Block direct 3001 except from Mac 2)"]
            BackendA["Backend Server A<br/>Node.js REST API (Port 3001)<br/>Header: X-Backend: A"]
            StandbyEdge["Extension E: Standby Edge Proxy<br/>Nginx (Port 8443)"]
            
            PF3 -.-> BackendA
        end

        subgraph M4 ["MAC-4 (10.7.21.68)"]
            PF4["Extension C: PF Firewall<br/>(Block direct 3002 except from Mac 2)"]
            BackendB["Backend Server B<br/>Node.js REST API (Port 3002)<br/>Header: X-Backend: B"]
            ClientNode["Evaluation Client Node<br/>curl, dig, Wireshark, Browser"]
            
            PF4 -.-> BackendB
        end

        Router --- M1
        Router --- M2
        Router --- M3
        Router --- M4
    end

    %% Client Resolution Flow
    ClientNode -->|"1a. Primary DNS Lookup (Port 53)"| DNS1
    ClientNode -.->|"1b. Backup DNS Failover (Port 53)"| DNS2
    
    %% Client HTTPS Request Flow
    ClientNode ==>|"2. HTTPS Request (Port 8443)"| EdgeProxy
    ClientNode -.->|"2b. Cutover to Standby Edge (Port 8443)"| StandbyEdge

    %% Reverse Proxy Upstream Distribution
    EdgeProxy ==>|"3a. Proxy Pass (HTTP 3001)"| PF3
    EdgeProxy ==>|"3b. Proxy Pass (HTTP 3002)"| PF4

    %% Blocked direct unauthorized client access
    ClientNode x-.-x|"DIRECT CONNECTION BLOCKED BY PF"| PF3
    ClientNode x-.-x|"DIRECT CONNECTION BLOCKED BY PF"| PF4
```

---

## 3. End-to-End Protocol Request & Failover Flows

### 3.1 Normal Request Flow (DNS → TLS → Reverse Proxy → Upstream)

```mermaid
sequenceDiagram
    autonumber
    actor Client as Client Node (MAC-4)
    participant DNS as Primary DNS (MAC-1 :53)
    participant Edge as Edge Proxy & LB (MAC-2 :8443)
    participant B_A as Backend A (MAC-3 :3001)
    participant B_B as Backend B (MAC-4 :3002)

    Note over Client,DNS: Step 1: DNS Resolution (UDP 53)
    Client->>DNS: Standard query A app.team1.test
    DNS-->>Client: Standard query response: 10.7.23.158 (TTL: 30s)

    Note over Client,Edge: Step 2: TCP 3-Way Handshake (TCP 8443)
    Client->>Edge: [SYN] (Src Ephemeral Port: >49152, Dst Port: 8443)
    Edge-->>Client: [SYN, ACK]
    Client->>Edge: [ACK]

    Note over Client,Edge: Step 3: TLS 1.3 Handshake (Presentation Layer)
    Client->>Edge: ClientHello (SNI = app.team1.test)
    Edge-->>Client: ServerHello, Certificate (CN=app.team1.test)
    Client->>Edge: Finished / Key Exchange
    Edge-->>Client: Finished

    Note over Client,B_B: Step 4: HTTP Request & Round-Robin Load Balancing
    Client->>Edge: GET /api/status (HTTP/2 Encrypted)
    alt Request #1, #3 (Round-Robin)
        Edge->>B_B: Forward HTTP GET to 10.7.21.68:3002
        B_B-->>Edge: HTTP 200 OK {"backend":"B"} (X-Backend: B)
    else Request #2, #4 (Round-Robin)
        Edge->>B_A: Forward HTTP GET to 10.7.22.2:3001
        B_A-->>Edge: HTTP 200 OK {"backend":"A"} (X-Backend: A)
    end
    Edge-->>Client: HTTP/2 200 OK (Encrypted Application Data Response)
```

### 3.2 Phase 2 High-Availability Failover & Resilience Flow

```mermaid
sequenceDiagram
    autonumber
    actor Client as Client Node (MAC-4)
    participant DNS1 as Primary DNS (MAC-1)
    participant DNS2 as Backup DNS (MAC-3)
    participant Edge as Edge Proxy (MAC-2)
    participant B_A as Backend A (MAC-3)
    participant B_B as Backend B (MAC-4)

    Note over DNS1: Primary DNS is Terminated (Outage)
    Client->>DNS1: DNS Query app.team1.test (Timeout)
    Client->>DNS2: Failover Query to Backup DNS (10.7.22.2:53)
    DNS2-->>Client: Response: 10.7.23.158 (Ext A: Seamless DNS Failover)

    Note over B_A: Backend A (Port 3001) Crashes
    Client->>Edge: GET /api/status
    Edge->>B_A: Proxy Pass to 10.7.22.2:3001 (Connection Refused!)
    Note over Edge: Nginx detects failure (proxy_next_upstream)
    Edge->>B_B: Instant Transparent Retry to 10.7.21.68:3002
    B_B-->>Edge: HTTP 200 OK (X-Backend: B)
    Edge-->>Client: HTTP/2 200 OK (Ext D: Zero Client Downtime!)

    Note over Client,B_A: Extension C: Direct Client Access Attempt
    Client->>B_A: GET http://10.7.22.2:3001/api/status
    Note over B_A: PF Firewall drops packet (not from 10.7.23.158)
    B_A--xClient: Connection Refused / Timed Out (Service Isolation)
```

---

## 4. OSI & TCP/IP Layer Mapping

| Layer # | OSI Layer Name | TCP/IP Layer Name | Protocol / Component in Project | Verification & Tooling |
|---|---|---|---|---|
| **7** | Application | Application | DNS (`dnsmasq`), HTTP/1.1, HTTP/2, REST APIs | `dig`, `curl -kv`, dnsmasq query logs |
| **6** | Presentation | Application / TLS | TLS 1.3 (OpenSSL, Nginx cert termination) | Certificate `CN=app.team1.test`, SNI |
| **5** | Session | Application / TLS | TLS Session Keys & Connection Management | Wireshark `ClientHello (SNI)` |
| **4** | Transport | Transport | TCP (8443, 3001, 3002), UDP (53) | Wireshark `tcp.flags.syn == 1`, `nc -zv` |
| **3** | Network | Internet | IPv4 Packets, Subnet Routing (`10.7.0.0/19`), PF Firewall | `ping -c 3`, `netstat -rn`, `pfctl -s rules` |
| **2** | Data Link | Network Access | Ethernet / Wi-Fi Frames (MAC Addresses) | `ifconfig en0`, Wireshark Ethernet frames |
| **1** | Physical | Network Access | 802.11ac/ax Wi-Fi RF Radio Signals | Local Wireless Access Point |

---

## 5. Phase 2 Resilience Architecture Reference

- **Extension A (Backup DNS)**: Client resolver table configured with Primary (`10.7.21.249`) and Backup (`10.7.22.2`). Transparent name resolution continuity upon Primary crash.
- **Extension B (DNS TTL & Cache Control)**: Authoritative TTL configured to `30s`. Client-side caching behavior and manual cache invalidation via `dscacheutil -flushcache`.
- **Extension C (Service Isolation)**: macOS Packet Filter (`pfctl`) deployed on Mac 3 and Mac 4, strictly isolating backend application ports to accept traffic exclusively from Mac 2 (`10.7.23.158`).
- **Extension D (High-Availability Failover)**: Nginx upstream cluster configured with `max_fails=1 fail_timeout=3s` and `proxy_next_upstream error timeout http_502`. Immediate automatic retry prevents dropped requests.
- **Extension E (Controlled Edge Migration)**: Standby Edge proxy configured on Mac 3; DNS authoritative record shifted to enable blue/green infrastructure cutover.
- **Extension F (Fault Troubleshooting Runbook)**: Layer-by-layer isolation script (`troubleshoot_fault.sh`) identifying DNS, TCP, TLS, or Application failures during faculty-injected fault challenges.
