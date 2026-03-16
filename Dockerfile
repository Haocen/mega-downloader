# --- Stage 1: Builder ---
FROM alpine:latest AS builder

# Ensure we have all necessary tools and libraries
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
    curl \
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

# THE FIX: Added -DUSE_VCPKG=OFF
# This forces CMake to use the 'apk' packages you installed above 
# instead of trying to clone vcpkg.
RUN rm -rf build && mkdir build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_VCPKG=OFF \
    -DENABLE_VARIOUS=ON \
    -DENABLE_DESKTOP_NOTIFICATIONS=OFF \
    -DENABLE_BACKTRACE=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install

# --- Stage 2: Runtime (Keep this as is from previous version) ---
FROM alpine:latest
RUN apk add --no-cache \
    c-ares crypto++ libcurl libgcc libstdc++ libuv libsodium \
    sqlite-libs pcre readline freeimage zlib nodejs npm su-exec shadow curl

COPY --from=builder /usr/local/bin/mega-* /usr/local/bin/
COPY --from=builder /usr/local/lib/libmega* /usr/local/lib/
RUN ldconfig /usr/local/lib || true

WORKDIR /usr/src/app
ENV PORT=3000 PUID=1000 PGID=1000 DOWNLOAD_DIR=/downloads
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN chmod +x entrypoint.sh && mkdir -p ${DOWNLOAD_DIR} && chown ${PUID}:${PGID} ${DOWNLOAD_DIR}

EXPOSE 3000
ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]