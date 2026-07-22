FROM alpine:3.23

# php-fpm + extensions
RUN apk add --no-cache \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-session \
    curl

# Adminer download
RUN mkdir -p /var/www/html && curl -fsSL -o /var/www/html/index.php \
    https://github.com/vrana/adminer/releases/download/v5.5.0/adminer-5.5.0.php

# php-fpm configuration (listen on the network)
COPY conf/www.conf /etc/php83/php-fpm.d/www.conf

EXPOSE 9000

CMD ["php-fpm83", "-F"]
