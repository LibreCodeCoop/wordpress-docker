ARG VERSION_WORDPRESS
ARG VERSION_PHP
FROM wordpress:${VERSION_WORDPRESS}-php${VERSION_PHP}-fpm

# Stop builds before publication when upstream PHP still lacks the October 2026 RCE fixes.
# CVE-2026-109618 / CVE-2026-109619; unsupported PHP branches fail closed.
RUN php -r '$minimum = ["8.2" => "8.2.35", "8.3" => "8.3.36", "8.4" => "8.4.27", "8.5" => "8.5.12"]; $series = PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION; if (!isset($minimum[$series]) || version_compare(PHP_VERSION, $minimum[$series], "<")) { fwrite(STDERR, "Unpatched or unsupported PHP runtime: " . PHP_VERSION . PHP_EOL); exit(1); }'


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