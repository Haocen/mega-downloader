# --- Stage 1: Builder ---
FROM alpine:latest AS builder

# build-base contains gcc, g++, make, and libc-dev
RUN apk add --update --no-cache \
    build-base \
    cmake \
    git \
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
    gtest-dev

WORKDIR /opt/MEGAcmd

# Clone with submodules
RUN git clone --recursive https://github.com/meganz/MEGAcmd.git .

# Build with CMake
# -DENABLE_BACKTRACE=OFF removes the need for the missing libexecinfo
RUN rm -rf build && mkdir build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_VARIOUS=ON \
    -DENABLE_DESKTOP_NOTIFICATIONS=OFF \
    -DENABLE_BACKTRACE=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install

# --- Stage 2: Runtime ---
FROM alpine:latest

# Shared libraries required for the mega-* binaries to run
RUN apk add --no-cache \
    c-ares \
    crypto++ \
    libcurl \
    libgcc \
    libstdc++ \
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

# Copy binaries and libraries from the builder
COPY --from=builder /usr/local/bin/mega-* /usr/local/bin/
COPY --from=builder /usr/local/lib/libmega* /usr/local/lib/

# Tell the dynamic linker where to find the MEGA libraries
RUN ldconfig /usr/local/lib || true

WORKDIR /usr/src/app

ENV PORT=3000 \
    PUID=1000 \
    PGID=1000 \
    DOWNLOAD_DIR=/downloads

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN chmod +x entrypoint.sh && \
    mkdir -p ${DOWNLOAD_DIR} && \
    chown ${PUID}:${PGID} ${DOWNLOAD_DIR}

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl --fail http://localhost:${PORT}/health || exit 1

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]