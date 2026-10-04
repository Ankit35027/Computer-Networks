#!/usr/bin/env python3
"""
Backend Application Server A
Computer Networks Course Project - Phase 1 Task C & F
Role: Application Server Instance A (Port 3001)
"""

import sys
import json
import hashlib
from datetime import datetime, timezone
from http.server import HTTPServer, BaseHTTPRequestHandler

DEFAULT_PORT = 3001
BACKEND_ID = "A"

class BackendHandler(BaseHTTPRequestHandler):
    server_version = "BackendServer/1.0"

    def log_message(self, format, *args):
        sys.stdout.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [Backend {BACKEND_ID}] {format % args}\n")

    def send_cors_and_common_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("X-Backend", BACKEND_ID)

    def handle_cached_response(self, content_bytes, content_type="application/json", is_head=False):
        etag = f'"{hashlib.md5(content_bytes).hexdigest()}"'
        client_etag = self.headers.get("If-None-Match")

        if client_etag == etag:
            self.send_response(304)
            self.send_header("ETag", etag)
            self.send_header("Cache-Control", "public, max-age=60")
            self.send_cors_and_common_headers()
            self.end_headers()
            return

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content_bytes)))
        self.send_header("Cache-Control", "public, max-age=60")
        self.send_header("ETag", etag)
        self.send_cors_and_common_headers()
        self.end_headers()
        if not is_head:
            self.wfile.write(content_bytes)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors_and_common_headers()
        self.end_headers()

    def process_request(self, is_head=False):
        url_path = self.path.split('?')[0]

        if url_path == "/" or url_path == "":
            payload = {
                "message": "Welcome to Backend Application Server A",
                "backend": BACKEND_ID,
                "status": "online",
                "port": self.server.server_port,
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
            body = json.dumps(payload, indent=2).encode('utf-8')
            self.handle_cached_response(body, "application/json", is_head=is_head)

        elif url_path == "/api/status":
            payload = {
                "status": "ok",
                "backend": BACKEND_ID,
                "message": "Backend A is healthy and operational",
                "server_port": self.server.server_port,
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
            body = json.dumps(payload, indent=2).encode('utf-8')
            
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
            self.send_cors_and_common_headers()
            self.end_headers()
            if not is_head:
                self.wfile.write(body)

        elif url_path == "/cached":
            cached_data = {
                "title": "HTTP Caching Demo Payload",
                "info": "This payload returns Cache-Control: max-age=60 and ETag. Repeat requests will receive 304 Not Modified.",
                "cache_policy": "max-age=60, public"
            }
            body = json.dumps(cached_data, indent=2).encode('utf-8')
            self.handle_cached_response(body, "application/json", is_head=is_head)

        else:
            payload = {
                "error": "Not Found",
                "path": url_path,
                "backend": BACKEND_ID
            }
            body = json.dumps(payload, indent=2).encode('utf-8')
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_cors_and_common_headers()
            self.end_headers()
            if not is_head:
                self.wfile.write(body)

    def do_GET(self):
        self.process_request(is_head=False)

    def do_HEAD(self):
        self.process_request(is_head=True)

def run(port=DEFAULT_PORT):
    server_address = ('0.0.0.0', port)
    httpd = HTTPServer(server_address, BackendHandler)
    print(f"==================================================")
    print(f" Starting Backend Server A on 0.0.0.0:{port}")
    print(f" Header: X-Backend: {BACKEND_ID}")
    print(f" Endpoints: GET /, GET /api/status, GET /cached")
    print(f"==================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Backend Server A.")
        httpd.server_close()

if __name__ == "__main__":
    port = DEFAULT_PORT
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass
    run(port)
