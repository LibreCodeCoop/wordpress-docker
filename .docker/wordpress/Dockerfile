ARG VERSION_WORDPRESS
ARG VERSION_PHP
FROM wordpress:${VERSION_WORDPRESS}-php${VERSION_PHP}-fpm

RUN apt-get update
RUN apt-get install -y \
    rsync \
    less

# Install PHP Extensions
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod uga+x /usr/local/bin/install-php-extensions && sync \
    && install-php-extensions \
    xdebug \
    intl

# Install wp-cli
RUN curl https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar --output /usr/bin/wp
RUN chmod +x /usr/bin/wp
RUN wp --info

COPY config/php.ini /usr/local/etc/php/conf.d/

COPY entrypoint.sh /var/www/scripts/entrypoint.sh

ENTRYPOINT [ "bash", "/var/www/scripts/entrypoint.sh" ]