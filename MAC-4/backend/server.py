#!/usr/bin/env python3
"""
COMPUTER NETWORKS COURSE PROJECT - PHASE 1
MACHINE ROLE: Mac 4 (Backend Server B + Test Client)
SERVICE: Backend Server B (Python 3 Alternative)
PORT: 3002 (Listens on 0.0.0.0 for LAN access)
"""

import http.server
import json
import socket
import socketserver
import time
from datetime import datetime, timezone
from urllib.parse import urlparse

PORT = 3002
HOST = "0.0.0.0"
BACKEND_ID = "B"
CACHE_ETAG = '"backend-b-v1.0"'
CACHE_MAX_AGE = 60

START_TIME = time.time()

def get_lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # doesn't need to be reachable
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

class BackendBHandler(http.server.BaseHTTPRequestHandler):
    def send_cors_and_common_headers(self, status_code=200, content_type="application/json"):
        self.send_response(status_code)
        self.send_header("Content-Type", content_type)
        self.send_header("X-Backend", BACKEND_ID)
        self.send_header("Server", "Python-Backend-B/Mac4")

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        timestamp = datetime.now(timezone.utc).isoformat()
        client_ip = self.client_address[0]

        print(f"[{timestamp}] [Backend B Python] GET {path} from {client_ip}")

        # 1. GET / - Basic confirmation
        if path == "/":
            data = {
                "message": "Backend Server B is running and accessible",
                "backend": BACKEND_ID,
                "role": "Application Server Instance B (Mac 4)",
                "host_ip": get_lan_ip(),
                "port": PORT,
                "timestamp": timestamp
            }
            body = json.dumps(data, indent=2).encode("utf-8")
            self.send_cors_and_common_headers(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        # 2. GET /api/status - Status endpoint
        if path == "/api/status":
            uptime = int(time.time() - START_TIME)
            data = {
                "backend": BACKEND_ID,
                "status": "ok",
                "uptime_seconds": uptime,
                "client_ip": client_ip,
                "hostname": socket.gethostname(),
                "timestamp": timestamp
            }
            body = json.dumps(data, indent=2).encode("utf-8")
            self.send_cors_and_common_headers(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        # 3. GET /api/cached - HTTP Caching (Task F)
        if path == "/api/cached":
            inm = self.headers.get("If-None-Match")
            if inm and (inm == CACHE_ETAG or inm == "*"):
                print(f"[{timestamp}] [Backend B Python] Cache hit! Client sent ETag {inm} -> 304")
                self.send_response(304)
                self.send_header("X-Backend", BACKEND_ID)
                self.send_header("Cache-Control", f"public, max-age={CACHE_MAX_AGE}")
                self.send_header("ETag", CACHE_ETAG)
                self.end_headers()
                return

            data = {
                "backend": BACKEND_ID,
                "status": "cached_resource",
                "etag": CACHE_ETAG,
                "max_age_seconds": CACHE_MAX_AGE,
                "content": "This response demonstrates HTTP caching headers (Cache-Control & ETag).",
                "fetched_at": timestamp
            }
            body = json.dumps(data, indent=2).encode("utf-8")
            self.send_cors_and_common_headers(200)
            self.send_header("Cache-Control", f"public, max-age={CACHE_MAX_AGE}")
            self.send_header("ETag", CACHE_ETAG)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        # 4. GET /health
        if path == "/health":
            body = json.dumps({"status": "healthy", "backend": BACKEND_ID}).encode("utf-8")
            self.send_cors_and_common_headers(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        # 404 Not Found
        body = json.dumps({"error": "Not Found", "backend": BACKEND_ID, "path": path}).encode("utf-8")
        self.send_cors_and_common_headers(404)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

if __name__ == "__main__":
    print("====================================================")
    print(f"  BACKEND SERVER B (Mac 4 - Python) RUNNING")
    print(f"  Listening on: http://{HOST}:{PORT}")
    print(f"  LAN Access  : http://{get_lan_ip()}:{PORT}")
    print(f"  Identifier  : Backend {BACKEND_ID} (X-Backend: {BACKEND_ID})")
    print("====================================================")
    with ReusableTCPServer((HOST, PORT), BackendBHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down Backend Server B...")
