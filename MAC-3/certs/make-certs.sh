#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# make-certs.sh  –  Mac 3 | Extension E: Generate self-signed TLS certs
# Generates a self-signed CA + a SAN cert for app.team1.test
#
# Usage:
#   cd certs/
#   chmod +x make-certs.sh
#   ./make-certs.sh
#
# Then install the CA cert on client machines (Mac 2 & Mac 4):
#   macOS: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DOMAIN="app.team1.test"
MAC3_IP="10.7.8.30"
DAYS=825          # macOS / iOS max validity
OUT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "── Generating CA key & self-signed certificate ──────────────────────────"
openssl genrsa -out "$OUT_DIR/ca.key" 4096

openssl req -new -x509 -days $DAYS \
    -key "$OUT_DIR/ca.key" \
    -out "$OUT_DIR/ca.crt" \
    -subj "/C=IN/ST=Lab/L=Campus/O=Team1Lab/OU=CA/CN=Team1Lab-RootCA"

echo "── Generating server key & CSR ──────────────────────────────────────────"
openssl genrsa -out "$OUT_DIR/${DOMAIN}.key" 2048

openssl req -new \
    -key "$OUT_DIR/${DOMAIN}.key" \
    -out "$OUT_DIR/${DOMAIN}.csr" \
    -subj "/C=IN/ST=Lab/L=Campus/O=Team1Lab/OU=Edge/CN=${DOMAIN}"

echo "── Signing server cert with CA (SAN included) ───────────────────────────"
cat > "$OUT_DIR/san.ext" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = mac3.team1.test
IP.1  = ${MAC3_IP}
IP.2  = 127.0.0.1
EOF

openssl x509 -req -days $DAYS \
    -in  "$OUT_DIR/${DOMAIN}.csr" \
    -CA  "$OUT_DIR/ca.crt" \
    -CAkey "$OUT_DIR/ca.key" \
    -CAcreateserial \
    -out "$OUT_DIR/${DOMAIN}.crt" \
    -extensions v3_req \
    -extfile "$OUT_DIR/san.ext"

rm -f "$OUT_DIR/${DOMAIN}.csr" "$OUT_DIR/san.ext"

echo ""
echo "✅  Certificates written to: $OUT_DIR"
echo "    ca.crt             ← Install on client machines as trusted root"
echo "    ${DOMAIN}.crt  ← nginx ssl_certificate"
echo "    ${DOMAIN}.key  ← nginx ssl_certificate_key"
echo ""
echo "To trust the CA on Mac 2 / Mac 4:"
echo "  sudo security add-trusted-cert -d -r trustRoot \\"
echo "    -k /Library/Keychains/System.keychain $OUT_DIR/ca.crt"
