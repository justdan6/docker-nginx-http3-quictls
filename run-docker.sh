#!/bin/sh
set -eu

cd "$(dirname "$0")"
ROOT=$(pwd)
TLS_DIR=${TLS_DIR:-"$ROOT/tests/.tls"}
if [ ! -f "$TLS_DIR/localhost.crt" ] || [ ! -f "$TLS_DIR/localhost.key" ]; then
  ./tests/generate-cert.sh "$TLS_DIR"
fi

exec docker run --rm "$@" \
  -p "127.0.0.1:${HTTP_PORT:-8888}:80" \
  -p "127.0.0.1:${HTTPS_PORT:-8889}:443/tcp" \
  -p "127.0.0.1:${HTTPS_PORT:-8889}:443/udp" \
  -v "$ROOT/tests:/static:ro" \
  -v "$ROOT/tests/modules.conf:/etc/nginx/main.d/modules.conf:ro" \
  -v "$ROOT/tests/perl_rewrite.conf:/etc/nginx/conf.d/perl_rewrite.conf:ro" \
  -v "$ROOT/tests/static.conf:/etc/nginx/conf.d/static.conf:ro" \
  -v "$ROOT/tests/https.conf:/etc/nginx/conf.d/https.conf:ro" \
  -v "$ROOT/tests/njs.conf:/etc/nginx/conf.d/njs.conf:ro" \
  -v "$ROOT/tests/njs:/opt/njs:ro" \
  -v "$TLS_DIR/localhost.crt:/etc/nginx/ssl/localhost.crt:ro" \
  -v "$TLS_DIR/localhost.key:/etc/nginx/ssl/localhost.key:ro" \
  --name "${CONTAINER_NAME:-test_nginx}" \
  "${IMAGE:-justdanz/nginx-http3-quictls:local}"
