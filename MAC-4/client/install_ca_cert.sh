#!/usr/bin/env bash
# ==============================================================================
# Task E: Install and Trust Team Root CA Certificate on Mac 4
# Allows curl and Safari/Chrome to verify https://app.teamX.test without -k
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_PATH="$1"

echo "=========================================================="
echo "          TASK E: INSTALL TEAM CA CERTIFICATE"
echo "=========================================================="

if [ -z "$CERT_PATH" ]; then
  if [ -f "$SCRIPT_DIR/rootCA.pem" ]; then
    CERT_PATH="$SCRIPT_DIR/rootCA.pem"
  elif [ -f "$SCRIPT_DIR/rootCA.crt" ]; then
    CERT_PATH="$SCRIPT_DIR/rootCA.crt"
  elif [ -f "$SCRIPT_DIR/ca.crt" ]; then
    CERT_PATH="$SCRIPT_DIR/ca.crt"
  fi
fi

if [ -z "$CERT_PATH" ] || [ ! -f "$CERT_PATH" ]; then
  echo "[!] Certificate file not found automatically."
  echo "Usage: ./client/install_ca_cert.sh <path-to-team-rootCA.crt>"
  echo ""
  echo "Steps:"
  echo "  1. Copy the root CA certificate created on Mac 2 or Mac 1"
  echo "     (e.g., rootCA.crt or ca.crt) to Mac 4."
  echo "  2. Run: ./client/install_ca_cert.sh /path/to/rootCA.crt"
  exit 1
fi

echo "Installing $CERT_PATH to macOS System Keychain..."
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_PATH"

if [ $? -eq 0 ]; then
  echo "[SUCCESS] Certificate trusted system-wide!"
  echo "You can now run: curl https://app.teamX.test (without -k flag)"
else
  echo "[ERROR] Failed to install certificate into keychain."
fi
