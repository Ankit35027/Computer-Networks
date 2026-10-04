#!/bin/bash
# ==============================================================================
# Script: start_nginx.sh
# Purpose: Start, Stop, or Reload Nginx for Mac 2 Edge Reverse Proxy
# Computer Networks Course Project - Phase 1 Task D & E
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NGINX_CONF="$PROJECT_ROOT/configs/nginx.conf"

NGINX_BIN=$(which nginx 2>/dev/null || echo "/opt/homebrew/bin/nginx")

if [ ! -x "$NGINX_BIN" ]; then
    echo "ERROR: Nginx binary not found at $NGINX_BIN."
    echo "Please install Nginx via Homebrew using: brew install nginx"
    exit 1
fi

case "$1" in
    start)
        echo "Testing Nginx Configuration..."
        $NGINX_BIN -t -c "$NGINX_CONF"
        echo "Starting Nginx with config: $NGINX_CONF..."
        $NGINX_BIN -c "$NGINX_CONF"
        echo "Nginx started successfully."
        ;;
    stop)
        echo "Stopping Nginx..."
        $NGINX_BIN -s stop -c "$NGINX_CONF" 2>/dev/null || pkill nginx || true
        echo "Nginx stopped."
        ;;
    reload)
        echo "Reloading Nginx Configuration..."
        $NGINX_BIN -s reload -c "$NGINX_CONF"
        echo "Nginx reloaded."
        ;;
    status)
        if pgrep nginx > /dev/null; then
            echo "Nginx is RUNNING (PIDs: $(pgrep nginx | tr '\n' ' '))"
        else
            echo "Nginx is STOPPED."
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|reload|status}"
        exit 1
        ;;
esac
