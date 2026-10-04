# Mac 1: Primary DNS Server Guide

**Machine Role**: Primary Authoritative & Recursive DNS Resolver  
**Target Domains**: `app.team1.test`, `api.team1.test`, `team1.test`  
**Assigned Subnet IP**: `10.7.8.10` (or assigned LAN IP)  

---

## 1. Prerequisites & Software Installation
Run the following command on Mac 1 to install the `dnsmasq` lightweight DNS server:
```bash
brew install dnsmasq
```

---

## 2. Configuration Setup
Copy the configuration file `configs/dnsmasq_primary.conf` from the project repository to Mac 1.

Verify the file contains the following rules:
```conf
port=53
no-hosts
log-queries
log-facility=/tmp/dnsmasq_primary.log

domain-needed
bogus-priv

server=8.8.8.8
server=1.1.1.1

# Short TTL (30s) for Phase 2 TTL & Migration testing (Extension B)
local-ttl=30

# Domain mapping for Team 1 (Points to Mac 2 Edge Proxy IP)
address=/app.team1.test/10.7.8.201
address=/api.team1.test/10.7.8.201
address=/team1.test/10.7.8.201
```

---

## 3. Starting the Service
Start `dnsmasq` with elevated privileges (required to bind to UDP/TCP port 53):
```bash
sudo dnsmasq -C /path/to/dnsmasq_primary.conf -d
```
*Or use Homebrew service manager*:
```bash
sudo brew services start dnsmasq
```

---

## 4. Verification Commands
On Mac 1 (or any client machine pointing to Mac 1):
```bash
dig @127.0.0.1 app.team1.test
```
**Expected Output**: Answers section must return `10.7.8.201` with `TTL 30`.

---

## 5. Phase 2 Resilience Demonstration (Extension A)
During Extension A evaluation, you will stop Mac 1's DNS service to prove client failover to Mac 3 (Backup DNS):
```bash
# To stop Primary DNS during failover test:
sudo pkill dnsmasq
```
