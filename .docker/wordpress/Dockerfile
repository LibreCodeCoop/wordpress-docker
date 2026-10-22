FROM wordpress:7.1.3-php8.3-fpm@sha256:788d6b34cb89997483ff2a08e2e04d1df28ce284ca046cd7990b0be10828c5b9



RUN apt-get update
RUN apt-get install -y \
    rsync \
    less \
    git \
    jq \
    yq

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

COPY --from=composer /usr/bin/composer /usr/bin/composer

COPY config/php.ini /usr/local/etc/php/conf.d/

COPY entrypoint.sh /var/www/scripts/entrypoint.sh

ENTRYPOINT [ "bash", "/var/www/scripts/entrypoint.sh" ]