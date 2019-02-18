FROM alpine:latest

ENV DOCROOT /docroot
WORKDIR $DOCROOT

ENV TZ='Asia/Shanghai' \
    SS_GIT_PATH="https://github.com/shadowsocks/shadowsocks-libev"

RUN apk --update add --no-cache bash wget unzip tzdata ca-certificates libcrypto1.0 libev libsodium mbedtls pcre c-ares php7 php7-apcu php7-ctype php7-curl php7-dom php7-fileinfo php7-ftp php7-iconv php7-intl php7-json php7-mbstring php7-mcrypt php7-mysqlnd php7-opcache php7-openssl php7-pdo php7-pdo_sqlite php7-phar php7-posix php7-session php7-simplexml php7-sqlite3 php7-tokenizer php7-xml php7-xmlreader php7-xmlwriter php7-zlib php7-gd php7-fpm nginx supervisor \
    && apk add --no-cache --virtual TMP git autoconf automake make build-base zlib-dev gettext-dev asciidoc xmlto libpcre32 libev-dev libsodium-dev libtool linux-headers mbedtls-dev openssl-dev pcre-dev c-ares-dev g++ gcc \
    && cd /tmp \
    && git clone ${SS_GIT_PATH} \
    && cd ${SS_GIT_PATH##*/} \
    && git submodule update --init --recursive \
    && ./autogen.sh \
    && ./configure --prefix=/usr && make \
    && make install \
    && apk del TMP \
    && rm -rf /tmp/* \
    && rm -rf /var/cache/apk/* \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \                     
    && echo '${TZ}' > /etc/timezone \
    && sed -i -E "s/127\.0\.0\.1:9000/\/var\/run\/php-fpm\/php-fpm.sock/" /etc/php7/php-fpm.d/www.conf \
    && mkdir /var/run/php-fpm \
    && mkdir -p /run/nginx \
    && mkdir -p /home/Software \
    && sed -i -E "s/error_log .+/error_log \/dev\/stderr warn;/" /etc/nginx/nginx.conf \
    && sed -i -E "s/access_log .+/access_log \/dev\/stdout main;/" /etc/nginx/nginx.conf \
    && mkdir -p /etc/supervisor.d/

ENV PHP_INI_DIR /etc/php7

COPY php.ini $PHP_INI_DIR/
COPY 1.conf /home/Software/
COPY 2.conf /home/Software/
COPY 3.conf /home/Software/
COPY supervisor.programs.ini /etc/supervisor.d/

COPY start.sh /
RUN chmod +x /start.sh

RUN adduser -D nonroot \
    && chmod a+x /start.sh \
    && chmod -R a+w /etc/php7/php-fpm.d \
    && chmod -R a+w /etc/nginx \
    && chmod a+w /var/run/php-fpm \
    && chmod -R a+w /run/nginx \
    && chmod -R a+wx /var/tmp/nginx \
    && chmod -R a+r /etc/supervisor* \
    && sed -i -E "s/^file=\/run\/supervisord\.sock/file=\/run\/supervisord\/supervisord.conf/" /etc/supervisord.conf \
    && mkdir -p /run/supervisord \
    && chmod -R a+w /run/supervisord \
    && chmod -R a+w /var/log \
    && apk add --update sudo \
    && echo "nonroot ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

ONBUILD COPY / $DOCROOT/
ONBUILD RUN \
    if [ -f "composer.json" ]; then \
        composer install --no-interaction || : \
    ; fi \
    && chmod -R a+w $DOCROOT

CMD ["/start.sh"]
