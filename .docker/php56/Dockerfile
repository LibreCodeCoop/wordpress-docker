FROM php:5.6.36-apache

RUN apt-get update

RUN apt-get install -y libbz2-dev libzip-dev zip libxml2-dev libpng-dev libjpeg62-turbo-dev libxpm-dev libfreetype6-dev libmcrypt-dev libxslt-dev libgmp-dev libcurl4-openssl-dev less

RUN ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h

RUN docker-php-ext-configure gd --with-freetype-dir --with-jpeg-dir --with-xpm-dir

RUN docker-php-ext-install bz2 zip calendar ctype dom exif gd gettext iconv json mcrypt mysql mysqli pdo_mysql shmop soap sockets xsl curl gmp wddx

RUN pecl install xdebug-2.2.7

RUN a2enmod rewrite

#Instala wp-cli
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
RUN php wp-cli.phar --info
RUN chmod +x wp-cli.phar
RUN mv wp-cli.phar /usr/bin/wp

# pending
# opcache sqlite3