# An alpine-based openresty installation with jwt module as well
FROM alpine:latest

MAINTAINER Nathan Toone "nathan@toonetown.com"

# The latest version of openresty and lua-resty-jwt
ENV OPENRESTY_VERSION 1.9.7.4
ENV LUA_RESTY_JWT_VERSION 0.1.5

# Environment variables to set
ENV OPENRESTY_PREFIX /usr/local/openresty
ENV NGINX_PREFIX ${OPENRESTY_PREFIX}/nginx

RUN addgroup -S openresty && adduser -D -S -h /var/cache/openresty -s /sbin/nologin -G openresty openresty \
    # Prerequisites for openresty and nginx (from official nginx dockerfile and openresty website)
    && apk add --no-cache --virtual .build-deps \
               gcc \
               libc-dev \
               make \
               openssl-dev \
               pcre-dev \
               zlib-dev \
               linux-headers \
               curl \
               gnupg \
               libxslt-dev \
               gd-dev \
               geoip-dev \
               perl-dev \
               musl-dev \
               ncurses-dev \
               readline-dev \
    \
    # Download and build openresty (using configs from official nginx dockerfile), then clean temporary directory
    && curl -fsSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -xvz \
    && cd openresty-${OPENRESTY_VERSION} \
    && ./configure --prefix=${OPENRESTY_PREFIX} \
                   --sbin-path=/usr/sbin/nginx \
                   --conf-path=/etc/openresty/nginx.conf \
                   --error-log-path=/var/log/openresty/error.log \
                   --http-log-path=/var/log/openresty/access.log \
                   --pid-path=/var/run/openresty.pid \
                   --lock-path=/var/run/openresty.lock \
                   --http-client-body-temp-path=/var/cache/openresty/client_temp \
                   --http-proxy-temp-path=/var/cache/openresty/proxy_temp \
                   --http-fastcgi-temp-path=/var/cache/openresty/fastcgi_temp \
                   --http-uwsgi-temp-path=/var/cache/openresty/uwsgi_temp \
                   --http-scgi-temp-path=/var/cache/openresty/scgi_temp \
                   --user=openresty \
                   --group=openresty \
                   --with-threads \
                   --with-stream \
                   --with-mail \
                   --with-file-aio \
                   --with-pcre-jit \
                   --with-ipv6 \
    && make \
    && make install \
    && mkdir /etc/openresty/conf.d \
    && mkdir -p /usr/share/openresty/ \
    && mv ${NGINX_PREFIX}/html /usr/share/openresty/html \
    && cd - \
    && rm -rf openresty-${OPENRESTY_VERSION} \
    \
    # Download and install lua-resty-jwt
    && curl -fsSL https://github.com/SkyLothar/lua-resty-jwt/archive/v${LUA_RESTY_JWT_VERSION}.tar.gz | tar -xvz \
    && find lua-resty-jwt-${LUA_RESTY_JWT_VERSION} -type d -name resty -exec cp -r {} ${OPENRESTY_PREFIX}/lualib \; \
    && rm -rf lua-resty-jwt-${LUA_RESTY_JWT_VERSION} \
    \
    # Clean up build dependencies, and install runtime dependencies
    && strip /usr/sbin/nginx $(find ${OPENRESTY_PREFIX} -type f -name '*.so*') \
    && apk add --no-cache --virtual .openresty-rundeps $( \
        scanelf --needed --nobanner /usr/sbin/nginx $(find ${OPENRESTY_PREFIX} -type f -name '*.so*') \
         | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
         | sort -u \
         | xargs -r apk info --installed \
         | sort -u \
    ) perl gettext \
    && apk del .build-deps \
    \
    # Set up the request and error logs so they go to the docker log collector
    && ln -sf /dev/stdout /var/log/openresty/access.log \
    && ln -sf /dev/stderr /var/log/openresty/error.log

# Copy our core configuration files (from official nginx container)
COPY nginx.conf /etc/openresty/nginx.conf
COPY nginx.vh.default.conf /etc/openresty/conf.d/default.conf

# Set working directory, other options, and run the nginx server
WORKDIR ${NGINX_PREFIX}
EXPOSE 80 443
CMD [ "nginx", "-g", "daemon off;" ]
