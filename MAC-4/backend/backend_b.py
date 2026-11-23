#!/usr/bin/env python3
"""
COMPUTER NETWORKS COURSE PROJECT - PHASE 1
Machine Role: Upstream REST Backend B (Port 3002) & Primary Client Evaluation Node
File: backends/backend_b.py
"""

import argparse
import hashlib
import http.server
import json
import socket
import socketserver
from datetime import datetime, timezone
from urllib.parse import urlparse

BACKEND_ID = "B"
# /cached body is byte-identical on Backend A (MAC-3/server.js) and Backend B,
# so both backends compute the SAME ETag. A conditional request (If-None-Match)
# therefore gets 304 no matter which backend round-robin picks.
# Keep this string in sync with SHARED_CACHE_CONTENT in MAC-3/server.js.
CACHE_CONTENT = '{"resource":"cached-demo","version":1,"cache_policy":"public, max-age=60"}'
CACHE_ETAG = f'"{hashlib.md5(CACHE_CONTENT.encode("utf-8")).hexdigest()}"'
CACHE_MAX_AGE = 60


def etag_matches(if_none_match, etag):
    """RFC 9110 weak comparison for If-None-Match.
    nginx gzip turns "abc" into W/"abc", and browsers may send a list of tags."""
    if not if_none_match:
        return False
    if if_none_match.strip() == "*":
        return True
    wanted = etag.replace("W/", "").strip()
    return any(tag.strip().replace("W/", "") == wanted for tag in if_none_match.split(","))

class BackendBHandler(http.server.BaseHTTPRequestHandler):
    # One Server header only (send_response() adds it automatically from these)
    server_version = "Backend-B/Mac4"
    sys_version = ""
    def send_cors_and_common_headers(self, status_code=200, content_type="application/json"):
        self.send_response(status_code)
        self.send_header("Content-Type", content_type)
        self.send_header("X-Backend", BACKEND_ID)

    # HEAD = same status + headers as GET, but no body (needed for `curl -I`).
    # Without this, Python's BaseHTTPRequestHandler answers HEAD with 501.
    def do_HEAD(self):
        self._is_head = True
        self.do_GET()

    def _write_body(self, body):
        if not getattr(self, "_is_head", False):
            self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        timestamp = datetime.now(timezone.utc).isoformat()
        client_ip = self.client_address[0]

        print(f"[{timestamp}] [Backend B] {self.command} {path} from {client_ip}", flush=True)

        # 1. GET / - Basic confirmation + Task F Caching
        if path == "/":
            inm = self.headers.get("If-None-Match")
            if etag_matches(inm, CACHE_ETAG):
                print(f"[{timestamp}] [Backend B] Conditional match on /! Returning 304 Not Modified")
                self.send_response(304)
                self.send_header("X-Backend", BACKEND_ID)
                self.send_header("Cache-Control", f"public, max-age={CACHE_MAX_AGE}")
                self.send_header("ETag", CACHE_ETAG)
                self.end_headers()
                return

            data = {
                "message": "Backend Server B is running",
                "backend": BACKEND_ID,
                "status": "ok",
                "server_port": self.server.server_port
            }
            body = json.dumps(data, indent=2).encode("utf-8")
            self.send_cors_and_common_headers(200)
            self.send_header("Cache-Control", f"public, max-age={CACHE_MAX_AGE}")
            self.send_header("ETag", CACHE_ETAG)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self._write_body(body)
            return

        # 2. GET /api/status - Status endpoint (Exact match for faculty spec)
        if path == "/api/status":
            data = {
                "status": "ok",
                "backend": BACKEND_ID,
                "server_port": self.server.server_port
            }
            body = json.dumps(data).encode("utf-8")
            self.send_cors_and_common_headers(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self._write_body(body)
            return

        # 3. GET /cached or /api/cached - HTTP Caching (Task F / Step 7)
        if path in ["/cached", "/api/cached"]:
            inm = self.headers.get("If-None-Match")
            # Remove quotes or compare direct
            if etag_matches(inm, CACHE_ETAG):
                print(f"[{timestamp}] [Backend B] Conditional match! Returning 304 Not Modified")
                self.send_response(304)
                self.send_header("X-Backend", BACKEND_ID)
                self.send_header("Cache-Control", f"public, max-age={CACHE_MAX_AGE}")
                self.send_header("ETag", CACHE_ETAG)
                self.end_headers()
                return

            body = CACHE_CONTENT.encode("utf-8")
            self.send_cors_and_common_headers(200)
            self.send_header("Cache-Control", f"public, max-age={CACHE_MAX_AGE}")
            self.send_header("ETag", CACHE_ETAG)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self._write_body(body)
            return

        # 404 Not Found
        body = json.dumps({"error": "Not Found", "backend": BACKEND_ID, "path": path}).encode("utf-8")
        self.send_cors_and_common_headers(404)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self._write_body(body)

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

def main():
    parser = argparse.ArgumentParser(description="Start Backend Server B")
    parser.add_argument("--port", type=int, default=3002, help="Port to listen on (default 3002)")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host interface (default 0.0.0.0)")
    args = parser.parse_args()

    print("====================================================")
    print(f"  BACKEND SERVER B (Mac 4) RUNNING")
    print(f"  Listening on: http://{args.host}:{args.port}")
    print(f"  ETag        : {CACHE_ETAG}")
    print(f"  Identifier  : Backend {BACKEND_ID} (X-Backend: {BACKEND_ID})")
    print("====================================================")
    print("Endpoints:")
    print(f"  GET http://127.0.0.1:{args.port}/api/status")
    print(f"  GET http://127.0.0.1:{args.port}/cached")
    print("====================================================")

    with ReusableTCPServer((args.host, args.port), BackendBHandler) as httpd:
        httpd.server_port = args.port
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down Backend Server B...")

if __name__ == "__main__":
    main()
