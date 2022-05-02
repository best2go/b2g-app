#!/usr/bin/env bash

# exit if any command fail
set -o errexit

# change pipeline exist status to be that of the rightmost
# command that fail, or zero if all exited successfully
set -o pipefail

if [[ ${PIPELINE_DEBUG} == true ]]; then
  # show command and arguments when executed,
  # preceded by PS4 value
	set -o xtrace
fi

RUNTIME="${RUNTIME:-local}"
# setup of the vendor, parameters, schema update, cache warmup.
# made at every `docker compose up -d`
if [[ ${RUNTIME} == "local" ]] && [[ ${1} == "php" ]]; then
  # we need such step to populate vendor and cache over to host
  # looking for more suitable way...
  COMPOSER_MEMORY_LIMIT=-1 composer install --no-autoloader --no-scripts --no-interaction --no-ansi -vv
  COMPOSER_MEMORY_LIMIT=-1 composer dump-autoload
  #COMPOSER_MEMORY_LIMIT=-1 composer run-script symfony-scripts --no-interaction --no-ansi -vv
  #php -d memory_limit=-1 bin/console cache:warmup --no-optional-warmers --env=dev -vvv
  #php -d memory_limit=-1 bin/console cache:warmup --no-optional-warmers --env=prod --no-debug -vvv
  php -d memory_limit=-1 bin/console assets:install --symlink --relative
fi

case ${1} in
  nginx)
    exec nginx -g 'daemon off;'
  ;;
  php|xphp)
    exec php-fpm --nodaemonize
  ;;
  *)
    exec "$@"
  ;;
esac
