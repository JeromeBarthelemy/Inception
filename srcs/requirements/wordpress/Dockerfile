FROM alpine:3.23

# php-fpm + extensions required by WordPress, wp-cli, mariadb client
RUN apk add --no-cache \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-phar \
    php83-curl \
    php83-dom \
    php83-exif \
    php83-fileinfo \
    php83-mbstring \
    php83-openssl \
    php83-xml \
    php83-zip \
    php83-gd \
    php83-session \
    php83-ctype \
    php83-tokenizer \
    php83-simplexml \
    php83-iconv \
    curl \
    mariadb-client

# wp-cli's shebang calls "php", but Alpine installs the binary as "php83"
RUN ln -sf /usr/bin/php83 /usr/bin/php

# Raise PHP memory limit (WordPress + wp-cli need more than the 128M default)
RUN echo "memory_limit = 256M" > /etc/php83/conf.d/99-memory-limit.ini

# Install wp-cli (WordPress command-line tool)
RUN curl -o /usr/local/bin/wp \
    https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# php-fpm configuration (listen on the network)
COPY conf/www.conf /etc/php83/php-fpm.d/www.conf

# Setup / configuration script
COPY tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/setup.sh"]
