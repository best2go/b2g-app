# syntax=docker/dockerfile:experimental
# COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose up --detach --build
ARG BASE_PHP=php:8.1

FROM ${BASE_PHP}-fpm-alpine AS base

# Configuration layer
ARG USER="www-data"
ARG UID="1000"
ARG GID="1000"
ARG HOME="/app"
#ARG APP_ENV="prod"
#ARG APP_DEBUG="false"
ARG COMPOSER_HOME="/var/cache/composer"
ARG XDG_CACHE_HOME="/var/cache/xdg"
ARG COMPOSER_MEMORY_LIMIT="-1"

ENV UID="${UID}" \
    GID="${GID}" \
    USER="${USER}" \
    HOME="${HOME}" \
    COMPOSER_HOME="${COMPOSER_HOME}" \
    XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
    PHP_INI_DIR="/usr/local/etc/php" \
    PHP_FPM_INI_DIR="/usr/local/etc/php-fpm.d"

#    APP_ENV="${APP_ENV}" \
#    APP_DEBUG="${APP_DEBUG}" \

# PHP_INI_DIR=/usr/local/etc/php (by default)

# Runtime dependencies, will be part of the finite image
ARG IMAGE_DEPS=" \
        bash \
        shadow \
    "

ARG EXTRA_PHP_EXT=" \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        zip \
        bcmath \
        opcache \
        simplexml \
        dom \
        json \
        curl \
        soap \
        gd \
        iconv \
        imagick \
        ssh2-1.3 \
        @composer \
    "

ARG EXTRA_XPHP_EXT="\
        pcov \
        xdebug-3.0.4 \
    "

COPY deployment/include/php/bin/install-php-extensions /usr/local/bin/install-php-extensions
COPY deployment/include/php/bin/php-fpm-healthcheck /usr/local/bin/php-fpm-healthcheck

RUN echo 'http://dl-cdn.alpinelinux.org/alpine/v3.8/main' >> /etc/apk/repositories && \
    apk add --update --no-cache ${IMAGE_DEPS} && \
    sync && \
    groupmod --gid "${GID}" "${USER}" && \
    usermod --uid "${UID}" --gid "${GID}" --home "${HOME}" "${USER}" && \
    install-php-extensions ${EXTRA_PHP_EXT} && \
    rm -rf /tmp/* /var/cache/apk/* && \
    mkdir --parents ${HOME} && \
    mkdir --parents ${COMPOSER_HOME} && \
    mkdir --parents ${XDG_CACHE_HOME} && \
    chown --recursive "${USER}:${USER}" "${HOME}" && \
    chown --recursive "${USER}:${USER}" "${COMPOSER_HOME}" && \
    chown --recursive "${USER}:${USER}" "${XDG_CACHE_HOME}"

HEALTHCHECK --interval=1m30s --timeout=30s --start-period=30s --retries=10 \
  CMD /usr/local/bin/php-fpm-healthcheck tcp://127.0.0.1:9000/ping

# ----------------------------------------------------------------------------------------------------------------------
FROM base AS composer

# introduce local composer cache ()
# ARG COMPOSER_HOME="/var/cache/composer"

USER ${USER}
WORKDIR ${HOME}

RUN mkdir var    && chown --recursive "${USER}:${USER}" var    && \
    mkdir vendor && chown --recursive "${USER}:${USER}" vendor

# TODO: remove b2g-parameters dependency
COPY --chown="${USER}:${USER}" composer.* ./
#COPY --chown="${USER}:${USER}" b2g-parameters/  ./

# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md
# https://github.com/FernandoMiguel/Buildkit
# RUN --mount=type=cache,id=composer_home,mode=0777,target=${COMPOSER_HOME},rw ls -la ${COMPOSER_HOME} && sleep 10
# RUN --mount=type=cache,id=composer_home,mode=0777,target=${COMPOSER_HOME},rw du -sh ${COMPOSER_HOME} && sleep 10
# RUN --mount=type=cache,id=composer_home,mode=0777,target=${COMPOSER_HOME},rw,sharing=locked \
#    composer install --no-autoloader --no-scripts --no-interaction --no-ansi --prefer-dist

RUN composer install --no-autoloader --no-scripts --no-plugins --no-interaction --no-ansi --prefer-dist --ignore-platform-reqs

#RUN echo -n "composer home :" && composer config home && sleep 10
#RUN --mount=type=cache,id=composer_home,mode=0777,target=${COMPOSER_HOME},rw ls -la ${COMPOSER_HOME} && sleep 10
#RUN --mount=type=cache,id=composer_home,mode=0777,target=${COMPOSER_HOME},rw du -sh ${COMPOSER_HOME} && sleep 10

ENTRYPOINT ["/usr/local/bin/composer"]
CMD ["install", "--no-interaction", "--no-scripts"]

# ----------------------------------------------------------------------------------------------------------------------
FROM base AS php

USER ${USER}
WORKDIR ${HOME}

RUN mkdir var    && chown --recursive "${USER}:${USER}" var    && \
    mkdir vendor && chown --recursive "${USER}:${USER}" vendor

COPY docker-entrypoint.sh               /docker-entrypoint.sh
COPY deployment/include/php/php-fpm.ini ${PHP_FPM_INI_DIR}/www.conf
COPY deployment/include/php/php.ini     ${PHP_INI_DIR}/conf.d/php.ini

COPY --chown="${USER}:${USER}" --from=composer /app/vendor /app/vendor
COPY --chown="${USER}:${USER}" . .

RUN COMPOSER_MEMORY_LIMIT=-1 composer dump-autoload --optimize

#RUN SHELL_VERBOSITY=2 COMPOSER_MEMORY_LIMIT=-1 composer run-script symfony-scripts --no-interaction --no-ansi
RUN php -d memory_limit=-1 bin/console cache:clear -vv --env=prod --no-debug && \
    php -d memory_limit=-1 bin/console cache:clear -vv --env=test --no-debug && \
    php -d memory_limit=-1 bin/console cache:clear -vv --env=dev             && \
    php -d memory_limit=-1 bin/console assets:install -vv && \
    echo "done."

ARG APP_OTP="app_otp"
ARG APP_TAG="app_tag"

ENV APP_OTP="${APP_OTP}" \
    APP_TAG="${APP_TAG}"

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["php"]

# ----------------------------------------------------------------------------------------------------------------------
FROM base AS xphp

RUN install-php-extensions ${EXTRA_XPHP_EXT} && \
    rm -f /usr/local/bin/install-php-extensions && \
    mkdir /opt/phpstorm-coverage && chown ${USER} /opt/phpstorm-coverage

USER ${USER}
WORKDIR ${HOME}

COPY docker-entrypoint.sh               /docker-entrypoint.sh

COPY deployment/include/php/php-fpm.ini ${PHP_FPM_INI_DIR}/www.conf
COPY deployment/include/php/xdebug.ini  ${PHP_INI_DIR}/conf.d/xdebug.ini
COPY deployment/include/php/opcache.ini ${PHP_INI_DIR}/conf.d/opcache.ini
COPY deployment/include/php/php.ini     ${PHP_INI_DIR}/conf.d/php.ini
COPY deployment/include/php/xphp.ini    ${PHP_INI_DIR}/conf.d/xphp.ini

COPY --from=php /app /app

ARG APP_OTP="app_otp"
ARG APP_TAG="app_tag"

ENV APP_OTP="${APP_OTP}" \
    APP_TAG="${APP_TAG}"

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["xphp"]

# ----------------------------------------------------------------------------------------------------------------------
FROM nginx:stable AS nginx

ARG USER="www-data"
ARG UID="1000"
ARG GID="1000"

RUN groupmod --gid "${GID}" "${USER}" && \
    usermod --uid "${UID}" --gid "${GID}" --home "/app/b2g-app/" "${USER}"

COPY deployment/include/nginx/00-config.conf    /etc/nginx/conf.d/00-config.conf
COPY deployment/include/nginx/x_request_id      /etc/nginx/x_request_id
COPY deployment/include/nginx/fastcgi_params    /etc/nginx/fastcgi_params
COPY deployment/include/nginx/b2g-app.conf      /etc/nginx/conf.d/b2g-conf.conf
COPY deployment/include/nginx/upstream-ecs.conf /etc/nginx/conf.d/upstream.conf
COPY docker-entrypoint.sh                       /docker-entrypoint.sh

# USER nginx 101:101 by default

COPY --from=php /app/public /app/b2g-app/public

WORKDIR "/app/b2g-app"
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx"]
