#!/bin/bash
# ==============================================================================
# Script: start_backends.sh
# Purpose: Launches Backend Server A (3001) and Backend Server B (3002)
# Computer Networks Course Project - Phase 1 Task C
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_ROOT/backends"

case "$1" in
    start)
        echo "Starting Backend Server A (Port 3001)..."
        pkill -f "backend_a.py" 2>/dev/null || true
        nohup python3 "$BACKEND_DIR/backend_a.py" 3001 > /tmp/backend_a.log 2>&1 &
        PID_A=$!
        echo $PID_A > /tmp/backend_a.pid
        echo "Backend A running (PID: $PID_A)"

        echo "Starting Backend Server B (Port 3002)..."
        pkill -f "backend_b.py" 2>/dev/null || true
        nohup python3 "$BACKEND_DIR/backend_b.py" 3002 > /tmp/backend_b.log 2>&1 &
        PID_B=$!
        echo $PID_B > /tmp/backend_b.pid
        echo "Backend B running (PID: $PID_B)"
        sleep 1
        ;;
    stop)
        echo "Stopping Backend Servers..."
        pkill -f "backend_a.py" 2>/dev/null || true
        pkill -f "backend_b.py" 2>/dev/null || true
        rm -f /tmp/backend_a.pid /tmp/backend_b.pid
        echo "Backend Servers stopped."
        ;;
    status)
        echo "Checking Backend Server Status..."
        echo -n "Backend A (3001): "
        curl -s http://127.0.0.1:3001/api/status | grep '"status": "ok"' > /dev/null && echo "ONLINE" || echo "DOWN"
        echo -n "Backend B (3002): "
        curl -s http://127.0.0.1:3002/api/status | grep '"status": "ok"' > /dev/null && echo "ONLINE" || echo "DOWN"
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
