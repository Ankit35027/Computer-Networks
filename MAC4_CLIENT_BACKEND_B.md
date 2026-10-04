# Mac 4: Backend B & Client Evaluation Node Guide

**Machine Role**: Upstream REST Backend B (Port 3002) & Primary Client Evaluation Node  
**Assigned Subnet IP**: `10.7.8.40` (or assigned LAN IP)  

---

## 1. Upstream Application Server B Setup
Copy `backends/backend_b.py` to Mac 4. Start Backend B on Port 3002:
```bash
python3 backends/backend_b.py --port 3002
```
Verify locally:
```bash
curl http://127.0.0.1:3002/api/status
```
**Expected Output**: `{"status": "ok", "backend": "B", "server_port": 3002}`

---

## 2. Client DNS Configuration
Configure network resolver settings on Mac 4:
- **Primary DNS**: `<Mac1_IP>` (e.g. `10.7.8.10`)
- **Secondary DNS**: `<Mac3_IP>` (e.g. `10.7.8.30`)

Verify name lookup:
```bash
dig app.team1.test
```
**Expected Output**: Must resolve to Mac 2 Edge Proxy IP (`10.7.8.201`).

---

## 3. Trust CA Certificate on Mac 4
Copy `certs/ca.crt` to Mac 4 and add it to System Keychain so HTTPS requests show zero warnings:
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt
```

---

## 4. Final Demonstration Commands (Section 8 Sequence from Client Node)

Run the following evaluation steps from Mac 4 towards Mac 2 Edge Proxy:

### Step 3: Domain Resolution
```bash
dig app.team1.test
```

### Step 4: HTTPS Service Access (No Certificate Warnings)
```bash
curl https://app.team1.test:8443/api/status
```

### Step 5: Load Balancing Distribution Test
```bash
for i in {1..10}; do curl -s -k https://app.team1.test:8443/api/status | grep "backend"; done
```
*Observe alternating output between `"backend": "A"` and `"backend": "B"`.*

### Step 7: HTTP Headers & Caching Demonstration
```bash
# First request to fetch ETag:
curl -i https://app.team1.test:8443/cached

# Conditional request (demonstrating HTTP 304 Not Modified):
curl -i -H 'If-None-Match: "8c6540340ce1e7794ebd1b527e03610a"' https://app.team1.test:8443/cached
```
**Expected Output**: `HTTP/2 304 Not Modified`
