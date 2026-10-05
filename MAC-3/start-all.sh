#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# start-all.sh  –  Mac 3: Start all services for the lab demonstration
#
# Run order:
#   1. Backend A (Node.js, port 3001)          — always
#   2. Backup DNS (dnsmasq, port 53)           — Extension A
#   3. Backend Firewall (pf isolation)         — Extension C   [sudo required]
#   4. Standby Edge (nginx, ports 8080/8443)   — Extension E   [sudo required]
#
# Usage:
#   chmod +x start-all.sh
#   sudo ./start-all.sh          # sudo needed for pf + nginx on port < 1024
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "═══════════════════════════════════════════════════════════════════════════"
echo "  Mac 3 Lab Services Launcher"
echo "═══════════════════════════════════════════════════════════════════════════"

# ── 1. Backend A ─────────────────────────────────────────────────────────────
echo ""
echo "▶  [1/4] Starting Backend A (Node.js) on port 3001..."
if lsof -ti:3001 > /dev/null 2>&1; then
    echo "   ℹ️  Port 3001 already in use – skipping (assumed already running)"
else
    node server.js &
    BACKEND_PID=$!
    sleep 1
    if kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo "   ✅ Backend A started (PID $BACKEND_PID)"
    else
        echo "   ❌ Backend A failed to start"
    fi
fi

# Quick health check
sleep 0.5
if curl -sf http://127.0.0.1:3001/api/status > /dev/null; then
    echo "   ✅ /api/status → OK"
else
    echo "   ⚠️  /api/status not responding yet (may need a moment)"
fi

# ── 2. Backup DNS (Extension A) ──────────────────────────────────────────────
echo ""
echo "▶  [2/4] Starting Backup DNS (dnsmasq) on port 53..."
if command -v dnsmasq > /dev/null 2>&1; then
    if pgrep -f "dnsmasq.*dnsmasq_backup" > /dev/null 2>&1; then
        echo "   ℹ️  dnsmasq backup already running – skipping"
    else
        sudo dnsmasq -C "$SCRIPT_DIR/configs/dnsmasq_backup.conf" --log-facility=/tmp/dnsmasq-backup.log &
        sleep 0.5
        echo "   ✅ dnsmasq backup started"
    fi
else
    echo "   ⚠️  dnsmasq not found. Install with:  brew install dnsmasq"
fi

# ── 3. Backend Firewall (Extension C) ────────────────────────────────────────
echo ""
echo "▶  [3/4] Applying pf backend isolation rules (Extension C)..."
if sudo pfctl -e -f "$SCRIPT_DIR/configs/pf_backend_isolation.conf" 2>&1; then
    echo "   ✅ pf rules loaded – port 3001 isolated to edge proxy only"
else
    echo "   ⚠️  pfctl failed (check configs/pf_backend_isolation.conf)"
fi

# ── 4. Standby Edge (Extension E) ────────────────────────────────────────────
echo ""
echo "▶  [4/4] Starting Standby Edge nginx (ports 8080/8443)..."
if command -v nginx > /dev/null 2>&1; then
    if sudo nginx -t -c "$SCRIPT_DIR/configs/nginx.conf" 2>/dev/null; then
        sudo nginx -c "$SCRIPT_DIR/configs/nginx.conf"
        echo "   ✅ nginx standby edge started"
    else
        echo "   ❌ nginx config test failed – run:  sudo nginx -t -c configs/nginx.conf"
    fi
else
    echo "   ⚠️  nginx not found. Install with:  brew install nginx"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "  All services launched. To stop:"
echo "    Backend A  →  kill \$(lsof -ti:3001)"
echo "    dnsmasq    →  sudo pkill dnsmasq"
echo "    pf rules   →  sudo pfctl -d"
echo "    nginx      →  sudo nginx -s stop"
echo "═══════════════════════════════════════════════════════════════════════════"
