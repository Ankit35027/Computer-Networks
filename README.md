# Computer Networks Course Project — Team 1
## Private Network Service Platform (`app.team1.test`), Phase 1 + Phase 2

A fully local 4-Mac network: private DNS (primary + backup), nginx edge with TLS and load balancing (primary + standby), two REST backends, pf backend isolation, and a layer-by-layer troubleshooting tool. No cloud.

## Where to find things (evaluator index)

| Looking for | Go to |
|---|---|
| Topology, IP/service table, request-flow diagrams | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| **Phase 2 Final Report** (changes, test results, troubleshooting findings, learning per extension) | [`docs/PHASE2_REPORT.md`](docs/PHASE2_REPORT.md) |
| Configuration bundle (dnsmasq, nginx, TLS notes, launch, firewall) | [`docs/CONFIGURATION_BUNDLE.md`](docs/CONFIGURATION_BUNDLE.md) |
| Troubleshooting runbook (Ext F) | [`docs/EXT_F_TROUBLESHOOTING_RUNBOOK.md`](docs/EXT_F_TROUBLESHOOTING_RUNBOOK.md) |
| Final demo, 11 steps | [`docs/DEMO_SCRIPT.md`](docs/DEMO_SCRIPT.md) |
| **Screenshot index** (what each image proves) | [`evidence/screenshots/README.md`](evidence/screenshots/README.md) |
| Phase 2 logs and pcaps | `MAC-1..4/evidence/phase2/` |
| Phase 1 evidence (Oct 2026) | `MAC-4/evidence/Phase_1_Evidence_Screenshots/`, `MAC-1/evidence/`, `MAC-4/evidence/phase1_final/` (full DNS+TCP+TLS pcap) |
| Project specification | [`docs/CN_Project_Doc_complete.md`](docs/CN_Project_Doc_complete.md) |

## Machines (current IPs in [`team.env`](team.env))

| Mac | IP | Role | Ports |
|---|---|---|---|
| Mac 1 | 10.7.5.14 | Primary DNS (dnsmasq) + test client | 53 |
| Mac 2 | 10.7.31.100 | Primary edge: nginx TLS termination + load balancer | 8443, 8080 |
| Mac 3 | 10.7.13.57 | Backend A (Node), backup DNS, standby edge | 3001, 53, 8443 |
| Mac 4 | 10.7.17.220 | Backend B (Python) + main test client | 3002 |

Subnet `10.7.0.0/19`, gateway `10.7.0.1`, domain `app.team1.test` (TTL 30 s).

## Quick start
See [`docs/CONFIGURATION_BUNDLE.md`](docs/CONFIGURATION_BUNDLE.md) §3. Health check from a client:
```bash
./scripts/diagnose.sh      # VERDICT: all layers healthy.
```

> Older per-machine guides in `docs/` and `MAC-*/README.md` were written during Phase 1 and may show earlier IPs (`10.7.21.249`, `10.7.23.158`, `10.7.22.2`, `10.7.21.68`) or placeholders (`10.7.8.x`). `team.env` and the documents linked above are current.
