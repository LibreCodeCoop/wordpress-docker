ARG VERSION_WORDPRESS
ARG VERSION_PHP
ARG WORDPRESS_BASE_IMAGE=wordpress:${VERSION_WORDPRESS}-php${VERSION_PHP}-fpm
FROM ${WORDPRESS_BASE_IMAGE}

RUN apt-get update
RUN apt-get install -y \
    rsync \
    less \
    git \
    jq \
    yq

# Install PHP Extensions
COPY --from=mlocati/php-extension-installer:2.13.2@sha256:4fd45396c16685266d32bf147a24ecd5e81029d3820295895bf4a90131190ac9 /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
    xdebug \
    intl

# Install wp-cli
RUN curl -fsSL https://github.com/wp-cli/wp-cli/releases/download/v2.12.0/wp-cli-2.12.0.phar --output /usr/bin/wp \
    && echo "be928f6b8ca1e8dfb9d2f4b75a13aa4aee0896f8a9a0a1c45cd5d2c98605e6172e6d014dda2e27f88c98befc16c040cbb2bd1bfa121510ea5cdf5f6a30fe8832  /usr/bin/wp" | sha512sum -c -
RUN chmod +x /usr/bin/wp
RUN wp --info

COPY --from=composer:2.11.2@sha256:5bcb28b8d0edc4091125f8218f9d088f998bdfc843f8fbb9a4beb4dcd8625684 /usr/bin/composer /usr/bin/composer

COPY config/php.ini /usr/local/etc/php/conf.d/

COPY entrypoint.sh /var/www/scripts/entrypoint.sh

ENTRYPOINT [ "bash", "/var/www/scripts/entrypoint.sh" ]