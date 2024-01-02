ARG VERSION_WORDPRESS
ARG VERSION_PHP
FROM wordpress:${VERSION_WORDPRESS}-php${VERSION_PHP}-fpm

# Install PHP Extensions
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod uga+x /usr/local/bin/install-php-extensions && sync \
    && install-php-extensions \
    xdebug \
    intl

# System Update and libicu-dev Installation
RUN apt-get update \
    && apt-get install -y \
      libicu-dev

# Install wp-cli
RUN curl https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar --output /usr/bin/wp
RUN chmod +x /usr/bin/wp
RUN wp --info

COPY config/php.ini /usr/local/etc/php/conf.d/
