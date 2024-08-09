#!/bin/bash

# Set uid of host machine
usermod --non-unique --uid "${HOST_UID}" www-data
groupmod --non-unique --gid "${HOST_GID}" www-data

rsync -r /usr/src/wordpress/ .

chown -R www-data:www-data .

php-fpm