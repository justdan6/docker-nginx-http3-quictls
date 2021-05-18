#!/bin/sh
docker run --rm \
  -p 0.0.0.0:8888:80 \
  -v "$PWD/tests":/static:ro \
  -v "$PWD/tests/static.conf":/etc/nginx/conf.d/static.conf:ro \
  --name test_nginx \
  -t macbre/nginx
