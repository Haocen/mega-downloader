# Ref: https://gitlab.com/danielquinn/megacmd-alpine/-/blob/master/Dockerfile

FROM alpine

RUN apk add --repository https://dl-cdn.alpinelinux.org/alpine/edge/testing --update --no-cache \
    c-ares \
    crypto++ \
    libcurl \
    libtool \
    libuv \
    libpcrecpp \
    libsodium \
    sqlite-libs \
    sqlite \
    pcre \
    readline \
    freeimage \
    zlib \
    \
    && apk add --repository https://dl-cdn.alpinelinux.org/alpine/edge/testing --update --no-cache --virtual .build-deps \
    autoconf \
    automake \
    c-ares-dev \
    crypto++-dev \
    curl \
    curl-dev \
    file \
    g++ \
    gcc \
    git \
    sqlite-dev \
    pcre-dev \
    libc-dev \
    libffi-dev \
    libressl-dev \
    libsodium \
    libsodium-dev \
    libuv-dev \
    make \
    openssl \
    openssl-dev \
    readline-dev \
    zlib-dev \
    freeimage-dev \
    \
    && git clone https://github.com/meganz/MEGAcmd.git /opt/MEGAcmd \
    && cd /opt/MEGAcmd \
    && git submodule update --init --recursive \
    && sh autogen.sh \
    && ./configure \
    && make -j $(nproc) \
    && make install \
    && cd / \
    && rm -rf /opt/MEGAcmd \
    \
    && apk del .build-deps \
    && find /usr/local/bin -type f  -executable -name 'mega-*' \
        -not -name 'mega-cmd-server' -not -name 'mega-exec' \
        -print0 | xargs -n 1 -0 -I{} sh -c 'if [ -f "{}" ]; then echo "Testing: {}"; {} --help > /dev/null || exit 255; fi' \
    && mega-put --help > /dev/null \
    && mega-export --help > /dev/null \
    && rm -rf /root/.megaCmd /tmp/*

# Install dependencies
RUN apk add --no-cache nodejs-lts npm su-exec shadow

WORKDIR /usr/src/app

# Copy package info and install
COPY package*.json ./
RUN npm install --production

# Copy app code
COPY . .
RUN chmod +x entrypoint.sh

# These are RUNTIME defaults, not build-time args
ENV PORT=3000
ENV HOST=0.0.0.0
ENV PUID=100
ENV PGID=100
ENV DOWNLOAD_DIR=/downloads

# Healthcheck: Every 30s, check if the server is responding on the PORT
# --fail makes curl return a non-zero exit code if the server returns 4xx/5xx
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl --fail http://localhost:${PORT}/health || exit 1

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]