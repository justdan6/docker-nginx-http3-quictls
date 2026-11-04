#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
IMAGE=${1:-justdanz/nginx-http3-quictls:local}
CURL_IMAGE=${CURL_IMAGE:-ghcr.io/macbre/curl-http3@sha256:c3a360869a4e132180f458f83af2ce67b873b2302739eda27274dad4f62155f8}
CURL_PLATFORM=${CURL_PLATFORM:-linux/amd64}
CONTAINER_NAME=nginx-http3-test-$$
TLS_DIR=$(mktemp -d)
export IMAGE CONTAINER_NAME TLS_DIR

cleanup() {
  docker logs "$CONTAINER_NAME" 2>/dev/null || true
  docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
  rm -rf "$TLS_DIR"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

request() {
  docker run --rm --platform "$CURL_PLATFORM" \
    --network "container:$CONTAINER_NAME" \
    -v "$TLS_DIR/localhost.crt:/tmp/localhost.crt:ro" \
    "$CURL_IMAGE" curl --fail --silent --show-error \
    --connect-timeout 2 --max-time 10 --cacert /tmp/localhost.crt -i "$@"
}

test "$(docker run --rm "$IMAGE" whoami)" = nginx
docker run --rm "$IMAGE" nginx -t
docker run --rm "$IMAGE" nginx -V 2>"$TLS_DIR/version"
NGINX_VERSION=$(docker run --rm "$IMAGE" printenv NGINX_VERSION)
grep -F "nginx/$NGINX_VERSION" "$TLS_DIR/version"
grep -F '+quic' "$TLS_DIR/version"
grep -F -- '--with-http_v3_module' "$TLS_DIR/version"
docker run --rm "$IMAGE" sh -c 'test "$(njs -v)" = "$NJS_VERSION"'
printf "console.log('Using njs v' + njs.version)\n" \
  | docker run -i --rm "$IMAGE" njs -q - | grep -F 'Using njs v'
docker run -i --rm "$IMAGE" njs -q - < tests/njs/scopes.js >"$TLS_DIR/scopes"
grep -Fx 'Passed njs lexical scope' "$TLS_DIR/scopes"
printf '${NGINX_VERSION}\n' \
  | docker run -i --rm "$IMAGE" sh -c 'test "$(envsubst)" = "$NGINX_VERSION"'

./tests/generate-cert.sh "$TLS_DIR"
# Random published ports avoid colliding with a developer's existing services.
HTTP_PORT=0 HTTPS_PORT=0 ./run-docker.sh -d

ready=false
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if request http://localhost/ >"$TLS_DIR/ready" 2>/dev/null; then
    ready=true
    break
  fi
  sleep 1
done
test "$ready" = true

request --http1.1 --compressed http://localhost/ >"$TLS_DIR/http1"
grep -F 'HTTP/1.1 200' "$TLS_DIR/http1"
grep -Ei '^content-encoding: br' "$TLS_DIR/http1"
grep -F '<p>It works!</p>' "$TLS_DIR/http1"

request http://localhost/FooBar >"$TLS_DIR/rewrite"
grep -F 'HTTP/1.1 301' "$TLS_DIR/rewrite"
grep -Ei '^x-rewrite: 1' "$TLS_DIR/rewrite"
grep -Ei '^location: http://localhost/foobar' "$TLS_DIR/rewrite"

request -H 'Host: njs' http://localhost/hello >"$TLS_DIR/njs"
grep -Ei '^x-njs: 1' "$TLS_DIR/njs"
grep -F 'Hello world from njs' "$TLS_DIR/njs"

request --http2 --compressed https://localhost/ >"$TLS_DIR/http2"
grep -F 'HTTP/2 200' "$TLS_DIR/http2"
grep -F '<p>It works!</p>' "$TLS_DIR/http2"

# --http3-only makes a TCP fallback fail this test.
request --http3-only --compressed https://localhost/ >"$TLS_DIR/http3"
grep -F 'HTTP/3 200' "$TLS_DIR/http3"
grep -Ei '^alt-svc: h3=":8889"; ma=86400' "$TLS_DIR/http3"
grep -Ei '^quic-status: h3' "$TLS_DIR/http3"
grep -F '<p>It works!</p>' "$TLS_DIR/http3"

for response in http1 http2 http3; do
  if grep -Eiq '^server:' "$TLS_DIR/$response"; then
    echo "Unexpected Server header in $response" >&2
    exit 1
  fi
done
echo 'Passed: non-root, modules, njs, envsubst, Brotli, rewrite, HTTP/1.1, HTTP/2 and HTTP/3.'
