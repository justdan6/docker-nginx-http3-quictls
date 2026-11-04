ARG ALPINE_VERSION=3.24.3

# https://github.com/nginx/nginx/blob/master/src/core/nginx.h
ARG NGINX_VERSION=1.31.8

# https://github.com/google/ngx_brotli
ARG NGX_BROTLI_COMMIT=53e0fb55f250f48fe80c0ddbf6c0f7103cdbaae1

# Latest published QuicTLS release; the successor repository has no releases yet.
# https://github.com/quictls/openssl/releases
ARG QUICTLS_TAG=openssl-3.3.0-quic1

# https://github.com/google/brotli/releases
ARG BROTLI_VERSION=1.2.1

# https://github.com/nginx/njs
ARG NJS_VERSION=1.0.2

# https://github.com/openresty/headers-more-nginx-module#installation
ARG HEADERS_MORE_VERSION=0.41

# https://github.com/leev/ngx_http_geoip2_module/releases
ARG GEOIP2_VERSION=3.4

# https://nginx.org/en/docs/http/ngx_http_v3_module.html
ARG CONFIG="\
	--build=nginx-$NGINX_VERSION-quictls-$QUICTLS_TAG \
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--modules-path=/usr/lib/nginx/modules \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
	--user=nginx \
	--group=nginx \
	--with-http_ssl_module \
	--with-http_realip_module \
	--with-http_addition_module \
	--with-http_sub_module \
	--with-http_dav_module \
	--with-http_flv_module \
	--with-http_mp4_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_random_index_module \
	--with-http_secure_link_module \
	--with-http_stub_status_module \
	--with-http_auth_request_module \
	--with-http_xslt_module=dynamic \
	--with-http_image_filter_module=dynamic \
	--with-http_geoip_module=dynamic \
	--with-http_perl_module=dynamic \
	--with-threads \
	--with-stream \
	--with-stream_ssl_module \
	--with-stream_ssl_preread_module \
	--with-stream_realip_module \
	--with-stream_geoip_module=dynamic \
	--with-http_slice_module \
	--with-mail \
	--with-mail_ssl_module \
	--with-compat \
	--with-file-aio \
	--with-http_v2_module \
	--with-http_v3_module \
	--add-module=/usr/src/ngx_brotli \
	--add-module=/usr/src/headers-more-nginx-module-$HEADERS_MORE_VERSION \
	--add-module=/usr/src/njs/nginx \
	--add-dynamic-module=/usr/src/ngx_http_geoip2_module \
	"

FROM alpine:${ALPINE_VERSION} AS base
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG NGINX_VERSION
ARG NGX_BROTLI_COMMIT
ARG BROTLI_VERSION
ARG QUICTLS_TAG
ARG HEADERS_MORE_VERSION
ARG NJS_VERSION
ARG GEOIP2_VERSION
ARG CONFIG

RUN \
	apk add --no-cache --virtual .build-deps \
	gcc \
	libc-dev \
	make \
	musl-dev \
	openssl-dev \
	pcre2-dev \
	zlib-dev \
	linux-headers \
	libxslt-dev \
	gd-dev \
	geoip-dev \
	perl-dev \
	&& apk add --no-cache --virtual .brotli-build-deps \
	ca-certificates \
	git \
	g++ \
	cmake \
	&& apk add --no-cache --virtual .geoip2-build-deps \
	libmaxminddb-dev \
	&& apk add --no-cache --virtual .njs-build-deps \
	readline-dev

WORKDIR /usr/src/

RUN \
	echo "Cloning nginx $NGINX_VERSION ..." \
	&& git clone --depth 1 --branch release-$NGINX_VERSION https://github.com/nginx/nginx.git /usr/src/nginx-$NGINX_VERSION

RUN \
	echo "Cloning brotli $NGX_BROTLI_COMMIT ..." \
	&& mkdir /usr/src/ngx_brotli \
	&& cd /usr/src/ngx_brotli \
	&& git init \
	&& git remote add origin https://github.com/google/ngx_brotli.git \
	&& git fetch --depth 1 origin $NGX_BROTLI_COMMIT \
	&& git checkout --recurse-submodules -q FETCH_HEAD \
	&& git submodule update --init --depth 1 \
	&& git -C deps/brotli fetch --depth 1 origin "refs/tags/v${BROTLI_VERSION}" \
	&& git -C deps/brotli checkout --detach FETCH_HEAD \
	&& cmake -S deps/brotli -B deps/brotli/out \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-DBUILD_SHARED_LIBS=OFF \
		-DBROTLI_DISABLE_TESTS=ON \
	&& cmake --build deps/brotli/out --parallel "$(getconf _NPROCESSORS_ONLN)" --target brotlienc brotlicommon

RUN \
	echo "Cloning QuicTLS ..." \
	&& cd /usr/src \
	&& git clone --depth 1 --branch "$QUICTLS_TAG" https://github.com/quictls/openssl.git openssl

RUN \
	echo "Downloading headers-more-nginx-module ..." \
	&& cd /usr/src \
	&& wget -q https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v${HEADERS_MORE_VERSION}.tar.gz -O headers-more-nginx-module.tar.gz \
	&& tar -xf headers-more-nginx-module.tar.gz

RUN \
	echo "Downloading ngx_http_geoip2_module ..." \
	&& git clone --depth 1 --branch ${GEOIP2_VERSION} https://github.com/leev/ngx_http_geoip2_module /usr/src/ngx_http_geoip2_module

RUN \
	echo "Cloning and configuring njs ..." \
	&& git clone --depth 1 --branch ${NJS_VERSION} https://github.com/nginx/njs.git /usr/src/njs \
	&& cd /usr/src/njs \
	&& ./configure \
	&& make njs \
	&& mv /usr/src/njs/build/njs /usr/sbin/njs \
	&& echo "njs v$(njs -v)"

RUN \
	echo "Building nginx ..." \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& ./auto/configure $CONFIG \
	--with-openssl="../openssl" \
	--with-openssl-opt=no-tests \
	&& make -j"$(getconf _NPROCESSORS_ONLN)"

# Backport nginx/njs#1143, fixed upstream after 1.0.2. Rebuild both consumers
# after applying it so changes to this patch can reuse the expensive TLS build.
COPY patches/njs-1.0.2-big-endian.patch /usr/src/njs-big-endian.patch
RUN \
	git -C /usr/src/njs apply /usr/src/njs-big-endian.patch \
	&& cd /usr/src/njs \
	&& ./configure --build-dir=build-cli \
	&& make -f build-cli/Makefile -j"$(getconf _NPROCESSORS_ONLN)" njs \
	&& mv build-cli/njs /usr/sbin/njs \
	&& make -f build/Makefile -j"$(getconf _NPROCESSORS_ONLN)" libnjs \
	&& make -C /usr/src/nginx-$NGINX_VERSION -j"$(getconf _NPROCESSORS_ONLN)"

RUN \
	cd /usr/src/nginx-$NGINX_VERSION \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	\
	# https://tools.ietf.org/html/rfc7919
	# https://github.com/mozilla/ssl-config-generator/blob/master/docs/ffdhe2048.txt
	&& wget -q https://ssl-config.mozilla.org/ffdhe2048.txt -O /etc/ssl/dhparam.pem \
	\
	# Copy only envsubst and its discovered dependencies into the final stage.
	&& apk add --no-cache --virtual .gettext gettext \
	\
	&& scanelf --needed --nobanner /usr/sbin/nginx /usr/sbin/njs /usr/lib/nginx/modules/*.so /usr/bin/envsubst \
	| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
	| sort -u \
	| xargs -r apk info --installed \
	| sort -u > /tmp/runDeps.txt

FROM alpine:${ALPINE_VERSION}
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
ARG NGINX_VERSION

ARG NJS_VERSION
ARG QUICTLS_TAG

ENV NGINX_VERSION=$NGINX_VERSION \
    NJS_VERSION=$NJS_VERSION \
    QUICTLS_TAG=$QUICTLS_TAG

COPY --from=base /tmp/runDeps.txt /tmp/runDeps.txt
COPY --from=base /etc/nginx /etc/nginx
COPY --from=base /usr/lib/nginx/modules/*.so /usr/lib/nginx/modules/
COPY --from=base /usr/sbin/nginx /usr/sbin/
COPY --from=base /usr/local/lib/perl5/site_perl /usr/local/lib/perl5/site_perl
COPY --from=base /usr/bin/envsubst /usr/local/bin/envsubst
COPY --from=base /etc/ssl/dhparam.pem /etc/ssl/dhparam.pem

COPY --from=base /usr/sbin/njs /usr/sbin/njs

# hadolint ignore=SC2046
RUN \
	addgroup --gid 101 -S nginx \
	&& adduser --uid 100 -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache --virtual .nginx-rundeps ca-certificates tzdata $(cat /tmp/runDeps.txt) \
	&& rm /tmp/runDeps.txt \
	&& ln -s /usr/lib/nginx/modules /etc/nginx/modules \
	# forward request and error logs to docker log collector
	&& mkdir -p /var/log/nginx /var/cache/nginx /etc/nginx/main.d \
	&& chown nginx:nginx /var/cache/nginx \
	&& touch /var/log/nginx/access.log /var/log/nginx/error.log \
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx.conf /etc/nginx/nginx.conf
COPY ssl_common.conf /etc/nginx/conf.d/ssl_common.conf

# njs version
RUN njs -v

# test the configuration
RUN nginx -V && nginx -t

EXPOSE 80 443/tcp 443/udp

STOPSIGNAL SIGTERM

# prepare to switching to non-root - update file permissions
RUN chown --verbose nginx:nginx \
	/var/run/nginx.pid

USER 100:101
RUN nginx -t
CMD ["nginx", "-g", "daemon off;"]
