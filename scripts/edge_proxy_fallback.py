#!/usr/bin/env python3
"""
Python-Based Edge Reverse Proxy & Load Balancer (Mac 2 Fallback)
Computer Networks Course Project - Phase 1 Task D & E
Provides zero-dependency TLS Termination & Round-Robin Load Balancing if Nginx is uninstalled.
"""

import sys
import os
import ssl
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
CERT_FILE = os.path.join(PROJECT_ROOT, "certs", "server.crt")
KEY_FILE = os.path.join(PROJECT_ROOT, "certs", "server.key")

UPSTREAM_SERVERS = [
    "http://127.0.0.1:3001",  # Backend A (Mac 3)
    "http://127.0.0.1:3002"   # Backend B (Mac 4)
]

request_counter = 0

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

class EdgeProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        sys.stdout.write(f"[Mac 2 Edge Proxy] {format % args}\n")

    def handle_proxy(self, method):
        global request_counter
        
        # Round-robin selection
        upstream = UPSTREAM_SERVERS[request_counter % len(UPSTREAM_SERVERS)]
        request_counter += 1
        
        target_url = f"{upstream}{self.path}"
        
        req_headers = {k: v for k, v in self.headers.items()}
        req_headers['X-Forwarded-For'] = self.client_address[0]
        req_headers['X-Forwarded-Proto'] = 'https' if self.server.socket.type == ssl.SOCK_STREAM else 'http'
        req_headers['Host'] = self.headers.get('Host', 'app.team1.test')

        req = urllib.request.Request(target_url, headers=req_headers, method=method)

        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                status_code = resp.status
                self.send_response(status_code)

                for k, v in resp.headers.items():
                    if k.lower() not in ['transfer-encoding', 'connection']:
                        self.send_header(k, v)

                self.send_header("X-Served-By", f"Mac2-Edge-Proxy (Upstream: {upstream})")
                self.end_headers()

                if method != "HEAD":
                    body = resp.read()
                    self.wfile.write(body)

        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for k, v in e.headers.items():
                self.send_header(k, v)
            self.end_headers()
            if method != "HEAD":
                self.wfile.write(e.read())

        except Exception as err:
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            if method != "HEAD":
                err_payload = f'{{"error": "502 Bad Gateway", "details": "{str(err)}", "edge": "Mac 2"}}'
                self.wfile.write(err_payload.encode('utf-8'))

    def do_GET(self):
        self.handle_proxy("GET")

    def do_HEAD(self):
        self.handle_proxy("HEAD")

def run_proxy(port=8443):
    server_address = ('0.0.0.0', port)
    httpd = ThreadedHTTPServer(server_address, EdgeProxyHandler)

    if os.path.exists(CERT_FILE) and os.path.exists(KEY_FILE):
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)
        httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
        print(f"==================================================")
        print(f" Mac 2 HTTPS Edge Proxy running on https://0.0.0.0:{port}")
        print(f" TLS Certificate: {CERT_FILE}")
        print(f" Upstreams: {', '.join(UPSTREAM_SERVERS)}")
        print(f"==================================================")
    else:
        print(f"WARNING: Certificate files not found at {CERT_FILE}. Running HTTP.")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Mac 2 Edge Proxy.")
        httpd.server_close()

if __name__ == "__main__":
    port = 8443
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass
    run_proxy(port)
