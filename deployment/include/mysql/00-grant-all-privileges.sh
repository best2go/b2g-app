#!/usr/bin/env bash

# provision mysql database
mysql \
    --user='root' \
    --password=${MYSQL_ROOT_PASSWORD} \
    --execute "GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'%';"
