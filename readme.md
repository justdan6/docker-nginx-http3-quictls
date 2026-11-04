# docker-nginx-http3-quictls

An nginx image with HTTP/3 (QUIC), HTTP/2, Brotli, njs, headers-more,
GeoIP/GeoIP2, Perl, XSLT and image-filter modules. It runs as the `nginx` user.
Forked from [macbre/docker-nginx-http3](https://github.com/macbre/docker-nginx-http3).

## Versions

Verified against upstream on 2026-11-03:

| Component | Version |
| --- | --- |
| [Alpine Linux](https://alpinelinux.org/releases/) | 3.24.3 |
| [nginx mainline](https://nginx.org/en/download.html) | 1.31.8 |
| [QuicTLS](https://github.com/quictls/openssl/releases) | openssl-3.3.0-quic1 |
| [njs](https://github.com/nginx/njs/releases) | 1.0.2 |
| [headers-more](https://github.com/openresty/headers-more-nginx-module/tags) | 0.41 |
| [ngx_brotli](https://github.com/google/ngx_brotli) | commit `53e0fb55f250f48fe80c0ddbf6c0f7103cdbaae1` |
| [Brotli library](https://github.com/google/brotli/releases) | 1.2.1 |
| [GeoIP2 module](https://github.com/leev/ngx_http_geoip2_module/releases) | 3.4 (already the latest release) |

njs 1.0.2 includes a regression affecting imports, local variables and function
parameters on 64-bit big-endian machines such as s390x. The build backports
[upstream fix 4ee6f12](https://github.com/nginx/njs/commit/4ee6f12facd274f2c1202c1bf9edbb24aa64c2d0),
and the smoke test checks lexical scope and an imported HTTP handler. Remove
the backport when upgrading to a release that includes that fix.

Alpine supplies the current packages available in its 3.24 repositories for
PCRE2, zlib, Perl, libmaxminddb and other system dependencies. Rebuild with
`--pull --no-cache` to refresh those packages. Brotli is explicitly built as a
static library; updating only the nginx module does not update its bundled library.

**QuicTLS maintenance limitation:** the latest published QuicTLS release is
still `openssl-3.3.0-quic1` (2024-09-30). The
[release repository was archived](https://github.com/quictls/openssl) in April
2025; its [successor](https://github.com/quictls/quictls) has no published
releases and uses a different build system. This image deliberately preserves
QuicTLS and pins its actual QUIC release. It does **not** provide a current,
maintained TLS release. For a maintained production TLS stack, plan a migration
to supported OpenSSL: [nginx supports QUIC with OpenSSL 3.5.1 or newer](https://nginx.org/en/docs/quic.html),
including early data. That migration changes the TLS implementation and is not
silently substituted here.

## Build and verify locally

Docker with Buildx, a POSIX shell and the OpenSSL CLI are required.

```sh
git clone https://github.com/justdan6/docker-nginx-http3-quictls.git
cd docker-nginx-http3-quictls
# In an existing checkout instead: git pull --ff-only

docker build --pull --no-cache -t justdanz/nginx-http3-quictls:local .
./tests/smoke.sh justdanz/nginx-http3-quictls:local
```

The smoke test checks the non-root user, all shipped dynamic modules, njs CLI
and HTTP handlers, `envsubst`, Perl rewrites, Brotli, hidden Server headers,
HTTP/1.1, HTTP/2 and **HTTP/3-only** with certificate verification. It generates
fresh disposable localhost certificates and cleans up the test container.
The HTTP/3 client is pinned by image digest and runs in the server's network
namespace, so this also works with Docker Desktop without host networking.
The client is amd64: Docker Desktop supplies emulation on Apple Silicon, and
CI installs QEMU on its native ARM64 runner. On other ARM Linux hosts, install
amd64 binfmt support or supply a native HTTP/3-capable client image via
`CURL_IMAGE` and `CURL_PLATFORM`.

To run the test site interactively:

```sh
./run-docker.sh
# In another terminal:
curl --cacert tests/.tls/localhost.crt https://localhost:8889/
```

The script binds the demo to localhost: HTTP on 8888 and HTTPS/QUIC on 8889
(TCP **and** UDP). Test credentials live in ignored `tests/.tls/` and are valid
for seven days; rerun `./tests/generate-cert.sh tests/.tls` to renew them.
These certificates and test configurations are only for local testing.

On macOS, Docker Desktop must be allowed to read the checkout's directory.
If bind mounts from `Documents` fail with `operation not permitted`, use a
checkout in a Docker-shared directory outside the protected folder, or grant
Docker Desktop access to that folder. See [Docker's file sharing settings](https://docs.docker.com/desktop/settings-and-maintenance/settings/#file-sharing).

## Publish an updated Docker Hub image

The GitHub Actions workflow first lints and builds/tests nginx on native amd64
and arm64 runners and tests the other architectures with QEMU. Only after all
five pass can it build and publish the five
existing platforms: `linux/amd64`, `linux/arm/v7`, `linux/arm64`,
`linux/ppc64le`, and `linux/s390x`.

Set these repository Actions secrets:

- `DOCKERHUB_USERNAME`: a Docker Hub account allowed to push the image.
- `DOCKERHUB_TOKEN`: a Docker Hub access token with write permission.

Merge the update into `master`. The successful workflow publishes
`justdanz/nginx-http3-quictls:latest` and a `sha-…` tag. You can also select
**Actions → Docker Image CI → Run workflow** on `master` to pull the base image
and rebuild without cache, refreshing Alpine packages too. From the GitHub CLI:

```sh
gh workflow run dockerimage.yml --ref master
```

Pull requests only build and test; they do not publish.

For a versioned release after merging:

```sh
git switch master
git pull --ff-only
git tag v1.31.8
git push origin v1.31.8
```

Use a new, unused version tag for subsequent releases. A release publishes
`1.31.8`, `1.31` and a commit tag. Only a successful build from `master` updates
`latest`, so releasing an older commit cannot roll that tag back.

Alternatively, publish directly from your updated checkout:

```sh
docker login
# Create a container-driver builder once (or select an existing one):
docker buildx create --name nginx-http3-builder --driver docker-container --use
docker buildx inspect --bootstrap
docker buildx build --pull --no-cache \
  --platform linux/amd64,linux/arm/v7,linux/arm64,linux/ppc64le,linux/s390x \
  -t justdanz/nginx-http3-quictls:1.31.8 \
  -t justdanz/nginx-http3-quictls:latest \
  --push .
```

Cross-platform builds require QEMU/binfmt support (included with Docker Desktop
and configured by CI). `--push` publishes the manifest to Docker Hub; a normal
`docker build` updates only your local image.

## Update a deployed container

After publishing finishes, run this in your deployment's Compose directory,
replacing `nginx` with your actual service name:

```sh
docker compose pull nginx
docker compose run --rm --no-deps nginx nginx -t
docker compose up -d --no-deps --force-recreate nginx
docker compose logs --tail=100 nginx
```

Your service should reference `justdanz/nginx-http3-quictls:latest` or the new
version tag. If it pins an older version/digest, update that reference first.
Pulling alone does not replace an existing container. For `docker run`
deployments, pull the new tag and recreate the container using your existing
ports, configuration, certificates and volume options.

Keep your production server configuration and valid certificates mounted.
The base nginx configuration includes `/etc/nginx/main.d/*.conf` for module
loading and `/etc/nginx/conf.d/*.conf` for HTTP/server configuration; it does
not define a default website. Preserve your configured container listen ports.
The demo uses 80 and 443; both TCP and UDP must be published for the HTTPS port.
Allow that UDP port through your firewall/load balancer and advertise the
**public** HTTPS port in `Alt-Svc` (normally `h3=":443"; ma=86400`).

Do not reuse dynamic `.so` modules from the previous image: they must match the
new nginx build. Mounted certificate keys, content and cache directories must
remain accessible to the unprivileged nginx user (UID 100, GID 101). Keep an
older image digest available if you need to roll back.
