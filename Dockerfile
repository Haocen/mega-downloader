# --- Stage 1: Builder ---
FROM alpine:latest AS builder

# Optimized build dependencies for CMake + Alpine
RUN apk add --update --no-cache \
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
    gtest-dev \
    libexecinfo-dev

WORKDIR /opt/MEGAcmd

# Use a specific version tag or master
RUN git clone --recursive https://github.com/meganz/MEGAcmd.git .

# Updated Build Command
# 1. We clear any existing build artifacts
# 2. We explicitly point CMake to the compiler
RUN rm -rf build && mkdir build && cd build && \
    cmake .. \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_VARIOUS=ON \
    -DENABLE_DESKTOP_NOTIFICATIONS=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install

# --- Stage 2: Final Runtime ---
FROM alpine:latest

# Runtime packages (No change here, just ensuring standard libs are present)
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
    curl \
    libexecinfo

# Copy compiled binaries and the MEGA shared library
COPY --from=builder /usr/local/bin/mega-* /usr/local/bin/
COPY --from=builder /usr/local/lib/libmega* /usr/local/lib/

# Essential: Let the system know where the new .so files are
RUN ldconfig /usr/local/lib || true

WORKDIR /usr/src/app

ENV PORT=3000 \
    DOWNLOAD_DIR=/downloads \
    PUID=1000 \
    PGID=1000

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN chmod +x entrypoint.sh && \
    mkdir -p ${DOWNLOAD_DIR} && \
    chown ${PUID}:${PGID} ${DOWNLOAD_DIR}

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl --fail http://localhost:${PORT}/health || exit 1

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]