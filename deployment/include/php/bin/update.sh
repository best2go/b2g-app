#!/bin/sh

# https://github.com/mlocati/docker-php-extension-installer
curl https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions \
  --output install-php-extensions \
  --location \
  --silent \
  && chmod +x ./install-php-extensions

# https://github.com/nick-lavrik/php-fpm-healthcheck
curl https://raw.githubusercontent.com/nick-lavrik/php-fpm-healthcheck/master/php-fpm-healthcheck \
  --output php-fpm-healthcheck \
  --location \
  --silent \
  && chmod +x ./php-fpm-healthcheck

# https://hub.docker.com/r/madnight/alpine-wkhtmltopdf-builder
#CID=$(docker create madnight/alpine-wkhtmltopdf-builder:0.12.5-alpine3.10-606718795)
#docker cp "${CID}:/bin/wkhtmltopdf" ./wkhtmltopdf
#docker rm -v "${CID}"
