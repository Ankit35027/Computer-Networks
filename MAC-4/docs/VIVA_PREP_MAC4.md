# Mac 4 Individual Viva Preparation Guide (Phase 1)

**Role**: Backend Server B + Test Client  
**Marks**: 10 Marks in Review 1 (Individual Understanding)

---

## 1. Core Architecture Questions

### Q1: What is the primary role of Mac 4 in the team architecture?
**Answer**:
Mac 4 has a dual role:
1. **Backend Server Instance B**: Runs a lightweight REST API on fixed TCP port `3002`, representing one of two replicated application instances in a production microservice cluster. It attaches the header `X-Backend: B` to identify itself.
2. **Test Client**: Acts as an end-user client machine on the LAN that configures Mac 1 as its DNS resolver, issues HTTPS requests to `https://app.teamX.test`, verifies load-balancing distribution across Backend A and B, tests caching, and captures network packets using Wireshark.

---

### Q2: Why MUST Backend B bind to `0.0.0.0` instead of `127.0.0.1`?
**Answer**:
- `127.0.0.1` (loopback interface `lo0`) only accepts connections originating from the local machine itself. If Backend B binds to `127.0.0.1`, Mac 2 (the Nginx edge server) cannot reach it across the Wi-Fi/LAN, causing Nginx upstream connection errors (`502 Bad Gateway`).
- Binding to `0.0.0.0` (INADDR_ANY) instructs the operating system kernel to accept incoming TCP connections on port 3002 across all available network interfaces, including the active LAN Wi-Fi interface (`en0`).

---

### Q3: Why does the client never need to know Backend B's IP address?
**Answer**:
Because Mac 2 acts as a **Reverse Proxy and Load Balancer**.
- The client only resolves and connects to the edge domain `app.teamX.test` (which points to Mac 2's IP address).
- Mac 2 hides the internal network topology. It terminates the client TLS connection and proxies the request internally to either Mac 3 (Backend A) or Mac 4 (Backend B).
- This provides security (internal servers are isolated from direct public/client exposure) and architectural flexibility (backends can scale or migrate without updating client configurations).

---

## 2. Protocols and Layers Questions

### Q4: Trace the step-by-step lifecycle of a request made from Mac 4.
**Answer**:
1. **DNS Resolution**:
   - Mac 4 sends a DNS query over **UDP port 53** to Mac 1 (`dnsmasq`) asking for the A record of `app.team1.test`.
   - Mac 1 responds with the private IP address of Mac 2 (Edge Nginx).
2. **TCP 3-Way Handshake**:
   - Mac 4 initiates a TCP connection to Mac 2 on port **443** (HTTPS):
     - `SYN` (from client ephemeral port, e.g. 52340 -> port 443)
     - `SYN-ACK` (from Mac 2 -> client)
     - `ACK` (from client -> Mac 2)
3. **TLS Handshake**:
   - Mac 4 sends `ClientHello` (TLS version, ciphers, SNI: `app.team1.test`).
   - Mac 2 responds with `ServerHello`, presents its Digital Certificate, and completes key exchange.
   - Both sides exchange `Finished` messages and establish symmetric encryption keys.
4. **HTTP Request & Upstream Proxy**:
   - Mac 4 transmits an encrypted HTTP `GET /api/status`.
   - Mac 2 decrypts the request (TLS termination).
   - Mac 2 looks up upstream backends and selects Backend B (round-robin).
   - Mac 2 creates a new TCP connection across the LAN to Mac 4 on port `3002`.
   - Mac 4's Backend B receives the request, attaches `X-Backend: B`, and sends back JSON.
   - Mac 2 encrypts the response and sends it back to Mac 4's client.

---

### Q5: How do the OSI and TCP/IP layers map to this project?
**Answer**:
| Protocol | Layer (OSI) | Layer (TCP/IP) | Project Component |
| :--- | :--- | :--- | :--- |
| **DNS, HTTP** | Application (Layer 7) | Application | dnsmasq, curl, REST API |
| **TLS** | Presentation / Session (L6/L5) | Application / Transport | Nginx OpenSSL termination |
| **TCP, UDP** | Transport (Layer 4) | Transport | TCP ports 443, 3001, 3002; UDP 53 |
| **IPv4, ICMP** | Network (Layer 3) | Internet | IP addresses (10.7.12.61), ping |
| **Ethernet / Wi-Fi**| Data Link (Layer 2) | Network Access | MAC addresses, 802.11 frames |

---

### Q6: What is the difference between an ephemeral port and a well-known port?
**Answer**:
- **Well-known / Service Port**: A fixed, standardized port that a server listens on so clients know where to send requests (e.g., DNS is UDP 53, HTTPS is TCP 443, Backend B is TCP 3002).
- **Ephemeral Port**: A temporary, dynamically allocated port chosen by the client operating system (typically in the range 49152–65535 on macOS) to uniquely identify the client's end of the TCP socket pair `(Client_IP:Ephemeral_Port, Server_IP:Service_Port)`.

---

## 3. Caching and Load Balancing Questions

### Q7: Explain HTTP caching: Fresh Request vs Conditional Request (304).
**Answer**:
- **Fresh Request (200 OK)**:
  - Client has no cached copy.
  - Server sends the response payload along with `Cache-Control: public, max-age=60` and `ETag: "backend-b-v1.0"`.
  - The client stores the content and ETag locally for 60 seconds.
- **Conditional Request (304 Not Modified)**:
  - When the cache revalidates, the client sends an HTTP request with the header `If-None-Match: "backend-b-v1.0"`.
  - The server verifies that the resource has not changed.
  - The server sends back `HTTP 304 Not Modified` with **no message body**.
  - This saves network bandwidth and reduces server processing load.

---

### Q8: What happens when Backend B is stopped during Phase 1?
**Answer**:
- When Backend B is stopped (`kill -9`), Nginx detects connection refused on port `3002`.
- Because Nginx is configured with upstream redundancy, it automatically re-routes subsequent requests to the remaining healthy instance, Backend A (port 3001 on Mac 3).
- Clients continue to receive `200 OK`, but 100% of responses contain `X-Backend: A`.
- Once Backend B is restarted, Nginx resumes round-robin distribution across both backends.
