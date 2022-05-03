FROM wordpress:5.9-php8.0-fpm

# Install xdebug
RUN pecl install xdebug-3.1.4 \
    && docker-php-ext-enable xdebug

# Install intl
RUN apt-get update \
    && apt-get install -y libicu-dev \
    && docker-php-ext-install intl

#Install wp-cli
RUN curl https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar --output /usr/bin/wp
RUN chmod +x /usr/bin/wp
RUN wp --info

COPY config/php.ini /usr/local/etc/php/conf.d/
