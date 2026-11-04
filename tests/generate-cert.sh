#!/bin/sh
set -eu

TLS_DIR=${1:?Usage: generate-cert.sh OUTPUT_DIRECTORY}
mkdir -p "$TLS_DIR"
# Disposable test credentials, generated locally instead of committed to git.
openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 7 \
  -subj /CN=localhost \
  -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1,IP:::1' \
  -keyout "$TLS_DIR/localhost.key" -out "$TLS_DIR/localhost.crt"
# nginx runs as a different, unprivileged UID inside the test container.
chmod 644 "$TLS_DIR/localhost.key" "$TLS_DIR/localhost.crt"
