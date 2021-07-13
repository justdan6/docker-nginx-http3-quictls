## What is this?

Stable and up-to-date [nginx](https://nginx.org/en/CHANGES) with [QUIC + **HTTP/3 experimental support**](https://hg.nginx.org/nginx-quic/shortlog/quic), [Google's `brotli` compression](https://github.com/google/ngx_brotli) and [Grade A+ SSL config](https://ssl-config.mozilla.org/)

nginx binary is built from [`quic` experimental branch](https://hg.nginx.org/nginx-quic/shortlog/quic). It's **not production-ready** yet!

## How to use this image
As this project is based on the official [nginx image](https://hub.docker.com/_/nginx/) look for instructions there. In addition to the standard configuration directives, you'll be able to use the brotli module specific ones, see [here for official documentation](https://github.com/google/ngx_brotli#configuration-directives)

```
docker pull macbre/nginx-http3:latest
```

You can fetch an image from [Github Containers Registry](https://github.com/macbre/docker-nginx-brotli/pkgs/container/nginx-http3) as well:

```
docker pull ghcr.io/macbre/nginx-http3:latest
```

## What's inside

```
$ docker run -it macbre/nginx-http3 nginx -V
nginx version: nginx/1.21.0 (quic-5b0c229ba5fe)
built by gcc 10.3.1 20210424 (Alpine 10.3.1_git20210424) 
built with OpenSSL 1.1.1 (compatible; BoringSSL) (running with BoringSSL)
TLS SNI support enabled
configure arguments: 
	--prefix=/etc/nginx 
	--sbin-path=/usr/sbin/nginx 
	--modules-path=/usr/lib/nginx/modules 
	--conf-path=/etc/nginx/nginx.conf 
	--error-log-path=/var/log/nginx/error.log 
	--http-log-path=/var/log/nginx/access.log 
	--pid-path=/var/run/nginx.pid 
	--lock-path=/var/run/nginx.lock 
	--http-client-body-temp-path=/var/cache/nginx/client_temp 
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp 
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp 
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp 
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp 
	--user=nginx 
	--group=nginx 
	--with-http_ssl_module 
	--with-http_realip_module 
	--with-http_addition_module 
	--with-http_sub_module 
	--with-http_dav_module 
	--with-http_flv_module 
	--with-http_mp4_module 
	--with-http_gunzip_module 
	--with-http_gzip_static_module 
	--with-http_random_index_module 
	--with-http_secure_link_module 
	--with-http_stub_status_module 
	--with-http_auth_request_module 
	--with-http_xslt_module=dynamic 
	--with-http_image_filter_module=dynamic 
	--with-http_geoip_module=dynamic 
	--with-http_perl_module=dynamic 
	--with-threads 
	--with-stream 
	--with-stream_ssl_module 
	--with-stream_ssl_preread_module 
	--with-stream_realip_module 
	--with-stream_geoip_module=dynamic 
	--with-http_slice_module 
	--with-mail 
	--with-mail_ssl_module 
	--with-compat 
	--with-file-aio 
	--with-http_v2_module 
	--with-http_v3_module 
	--add-module=/usr/src/ngx_brotli 
	--with-cc-opt=-I../boringssl/include 
	--with-ld-opt='-L../boringssl/build/ssl -L../boringssl/build/crypto'
```

## SSL Grade A+ handling

Please refer to [Mozilla's SSL Configuration Generator](https://ssl-config.mozilla.org/). This image has `https://ssl-config.mozilla.org/ffdhe2048.txt` DH parameters for DHE ciphers fetched and stored in `/etc/ssl/dhparam.pem`:

```
    ssl_dhparam /etc/ssl/dhparam.pem;
```

## nginx config files includes

* `.conf` files mounted in `/etc/nginx/main.d` will be included in the `main` nginx context (e.g. you can call [`env` directive](http://nginx.org/en/docs/ngx_core_module.html#env) there)
* `.conf` files mounted in `/etc/nginx/conf.d` will be included in the `http` nginx context

## QUIC + HTTP/3 support

<img width="577" alt="Screenshot 2021-05-19 at 16 31 10" src="https://user-images.githubusercontent.com/1929317/118840921-baf7d300-b8bf-11eb-8c0f-e57d573a28ce.png">

Please refer to `tests/https.conf` config file for an example config used by the tests. And to Cloudflare docs on [how to enable http/3 support in your browser](https://developers.cloudflare.com/http3/firefox).

```
server {
    # quic and http/3
    listen 443 http3 reuseport;

    # http/2 and http/1.1
    listen 443 ssl http2;

    server_name localhost;  # customize to match your domain

    # you need to mount these files when running this container
    ssl_certificate     /etc/nginx/ssl/localhost.crt;
    ssl_certificate_key /etc/nginx/ssl/localhost.key;

    # Enable all TLS versions (TLSv1.3 is required for QUIC).
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;

    # 0-RTT QUIC connection resumption
    ssl_early_data on;

    # Add Alt-Svc header to negotiate HTTP/3.
    add_header alt-svc 'h3-27=":443"; ma=86400, h3-28=":443"; ma=86400, h3-29=":443"; ma=86400';

    # Sent when QUIC was used
    add_header QUIC-Status $quic;

    location / {
        # your config
    }
}
```

Refer to `run-docker.sh` script on how to run this container and properly mount required config files and assets.

## Development

Building an image:

```
docker pull ghcr.io/macbre/nginx-http3:latest
DOCKER_BUILDKIT=1 docker build . -t macbre/nginx --cache-from=ghcr.io/macbre/nginx-http3:latest --progress=plain
```
