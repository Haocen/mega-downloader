# --- Stage 1: Builder ---
FROM alpine:latest AS builder

RUN apk add --update --no-cache --virtual .build-deps \
    autoconf \
    automake \
    c-ares-dev \
    crypto++-dev \
    curl-dev \
    file \
    g++ \
    gcc \
    git \
    libtool \
    libuv-dev \
    make \
    openssl-dev \
    pcre-dev \
    readline-dev \
    sqlite-dev \
    zlib-dev \
    freeimage-dev \
    libsodium-dev \
    libc-dev

# Clone and Build MEGAcmd
WORKDIR /opt/MEGAcmd
RUN git clone --recursive https://github.com/meganz/MEGAcmd.git . \
    && sh autogen.sh \
    && ./configure --without-termcap \
    && make -j $(nproc) \
    && make install

# --- Stage 2: Final Runtime ---
FROM alpine:latest

# Define Runtime Environment Variables
ENV PORT=3000 \
    HOST=0.0.0.0 \
    PUID=1000 \
    PGID=1000 \
    DOWNLOAD_DIR=/downloads \
    NODE_ENV=production

# Install only RUNTIME dependencies
RUN apk add --no-cache \
    c-ares \
    crypto++ \
    libcurl \
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

# Copy compiled binaries from builder
COPY --from=builder /usr/local/bin/mega-* /usr/local/bin/
COPY --from=builder /usr/local/lib/libmega* /usr/local/lib/
# Refresh library cache
RUN ldconfig /usr/local/lib || true

WORKDIR /usr/src/app

# Install Node dependencies (using cache efficiently)
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .
RUN chmod +x entrypoint.sh

# Security: Ensure download dir exists
RUN mkdir -p ${DOWNLOAD_DIR} && chown ${PUID}:${PGID} ${DOWNLOAD_DIR}

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl --fail http://localhost:${PORT}/health || exit 1

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]