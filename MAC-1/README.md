# Computer Networks Course Project — Team 1
## Private Network Service Platform (Two-Phase Implementation)

### Machine Role: Mac 1 (Primary DNS Server + Test Client)
- **Assigned Domain**: `app.team1.test`, `api.team1.test`, `team1.test`
- **Mac 1 IPv4**: `10.7.21.249` (Port 53 UDP/TCP)
- **Mac 2 IPv4 (Edge Proxy)**: `10.7.23.158` (Port 8443 TCP)
- **Mac 3 IPv4 (Backend A)**: `10.7.22.2` (Port 3001 TCP)
- **Mac 4 IPv4 (Backend B)**: `10.7.21.68` (Port 3002 TCP)

---

## 📁 Project Directory Structure

```text
Computer Networks/
├── docs/
│   ├── Architecture_Document.md       # Deliverable 1: Topology, IP Table, & Sequence Diagram
│   └── CN_Project_Doc_complete.md      # Course Project Specification & Evaluation Rubric
├── configs/
│   └── dnsmasq.conf                    # Production DNS Configuration (port 53, TTL 30, Edge mappings)
├── scripts/
│   ├── 01_lan_verify.sh                # Task A: Network interface info & ping verification
│   ├── 02_dns_install.sh               # Task B: dnsmasq deployment & service starter
│   ├── 03_dns_test.sh                  # Task B: Automated dig/nslookup verification suite
│   ├── wireshark_capture.sh            # Task G: Live packet capture on en0 & auto-open in Wireshark
│   └── capture_commands.sh             # Batch evidence collector
├── evidence/
│   ├── captures/                       # Raw .pcapng packet capture files
│   │   ├── wireshark_capture_20261004_213449.pcapng
│   │   └── ...
│   ├── screenshots/                    # All 14 Evaluation Screenshots (SS01 - SS14)
│   │   └── README.md                   # Screenshot index and naming convention guide
│   ├── logs/                           # Curl verbose, dig output, and header logs
│   └── checklist.md                    # Review 1 & Review 2 evaluation checklist
└── README.md                           # Master Project Overview
```

---

## 🚀 Quick Run Guide

### 1. Start the DNS Server
```bash
sudo sh -c 'pkill -f dnsmasq 2>/dev/null; sleep 1; /opt/homebrew/sbin/dnsmasq --conf-file=/opt/homebrew/etc/dnsmasq.conf'
sudo lsof -i :53 -nP
```

### 2. Verify DNS Resolution
```bash
dig @127.0.0.1 app.team1.test
```

### 3. Test Full Stack (DNS → Nginx → Load Balanced Backends)
```bash
for i in {1..6}; do
    curl -sk --resolve app.team1.test:8443:10.7.23.158 https://app.team1.test:8443/api/status
    echo ""
done
```

### 4. Capture Packets for Wireshark
```bash
sudo bash scripts/wireshark_capture.sh
```

---

## 📋 Evaluation Checklist Reference
See [`evidence/checklist.md`](evidence/checklist.md) and [`docs/Architecture_Document.md`](docs/Architecture_Document.md) for full protocol flow diagrams and layer-by-layer technical explanations.
