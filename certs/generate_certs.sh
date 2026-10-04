#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=================================================="
echo " Generating TLS/SSL Certificates for Mac 2 Edge"
echo " Domain: app.team1.test / api.team1.test"
echo "=================================================="

# 1. Generate Root CA Private Key & Certificate
echo "[1/4] Generating Local Root CA..."
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -out ca.crt \
  -subj "/C=US/ST=State/L=City/O=Team1 Network Project/OU=Root CA/CN=Team1 Local Root CA"

# 2. Generate Server Private Key
echo "[2/4] Generating Server Private Key..."
openssl genrsa -out server.key 2048

# 3. Generate Certificate Signing Request (CSR)
echo "[3/4] Creating Certificate Signing Request (CSR) with SAN..."
openssl req -new -key server.key -out server.csr \
  -config openssl_san.cnf

# 4. Sign Server Certificate with Root CA
echo "[4/4] Signing Server Certificate using Root CA..."
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 825 -sha256 \
  -extfile openssl_san.cnf -extensions v3_req

echo "=================================================="
echo " Certificates successfully generated in $SCRIPT_DIR"
echo " Files created:"
echo "   - ca.crt         (Distribute to client Macs to trust)"
echo "   - ca.key         (Root CA private key)"
echo "   - server.crt     (Nginx SSL Certificate)"
echo "   - server.key     (Nginx SSL Private Key)"
echo "=================================================="
echo "To trust ca.crt on macOS, run:"
echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt"
echo "=================================================="
