#!/usr/bin/env bash
# ==============================================================================
# Start Backend Server B (Mac 4)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=3002

echo ">>> Checking if port $PORT is already in use..."
PID=$(lsof -ti :$PORT 2>/dev/null)
if [ -n "$PID" ]; then
  echo "[!] Port $PORT is already in use by PID $PID. Killing old process..."
  kill -9 $PID
  sleep 1
fi

if command -v node >/dev/null 2>&1; then
  echo ">>> Launching Node.js Backend Server B on port $PORT..."
  exec node "$SCRIPT_DIR/server.js"
elif command -v python3 >/dev/null 2>&1; then
  echo ">>> Launching Python 3 Backend Server B on port $PORT..."
  exec python3 "$SCRIPT_DIR/server.py"
else
  echo "[ERROR] Neither Node.js nor Python3 found on this system!"
  exit 1
fi
