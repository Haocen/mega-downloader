# --- Stage 1: Builder ---
FROM alpine:latest AS builder

# Added cmake and extra dependencies required for the modern build
RUN apk add --update --no-cache --virtual .build-deps \
    cmake \
    git \
    g++ \
    gcc \
    make \
    autoconf \
    automake \
    libtool \
    file \
    binutils \
    gnupg \
    linux-headers \
    c-ares-dev \
    crypto++-dev \
    curl-dev \
    freeimage-dev \
    libsodium-dev \
    libuv-dev \
    openssl-dev \
    pcre-dev \
    readline-dev \
    sqlite-dev \
    zlib-dev \
    gtest-dev

WORKDIR /opt/MEGAcmd

# Clone with submodules
RUN git clone --recursive https://github.com/meganz/MEGAcmd.git .

# CMake Build Process
RUN mkdir -p build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_VARIOUS=ON \
    -DENABLE_DESKTOP_NOTIFICATIONS=OFF && \
    make -j$(nproc) && \
    make install

# --- Stage 2: Final Runtime ---
FROM alpine:latest

ENV PORT=3000 \
    HOST=0.0.0.0 \
    PUID=1000 \
    PGID=1000 \
    DOWNLOAD_DIR=/downloads \
    NODE_ENV=production

# Install Runtime Shared Libraries
RUN apk add --no-cache \
    c-ares \
    crypto++ \
    libcurl \
    libgcc \
    libstdc++ \
    libtool \
    libuv \
    libsodium \
    sqlite-libs \
    pcre \
    readline \
    freeimage \
    zlib \
    nodejs \
    npm \
    su-exec \
    shadow \
    curl

# Copy binaries and libraries from builder
COPY --from=builder /usr/local/bin/mega-* /usr/local/bin/
COPY --from=builder /usr/local/lib/libmega* /usr/local/lib/

# Essential for Alpine to recognize the new libraries in /usr/local/lib
RUN ldconfig /usr/local/lib || true

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN chmod +x entrypoint.sh

# Ensure the download directory exists with correct permissions
RUN mkdir -p ${DOWNLOAD_DIR} && chown ${PUID}:${PGID} ${DOWNLOAD_DIR}

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl --fail http://localhost:${PORT}/health || exit 1

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]