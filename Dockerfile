# --- Stage 1: Builder ---
FROM alpine:latest AS builder

# We need bash, curl, and all dev-libs
RUN apk add --update --no-cache \
    build-base \
    cmake \
    git \
    bash \
    curl \
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
RUN git clone --recursive https://github.com/meganz/MEGAcmd.git .

# THE FIX: 
# 1. Ensure bash is mapped where scripts expect it (/usr/bin/bash vs /bin/bash)
# 2. Force the CMake variable to think vcpkg is already found or not needed
# 3. Use a broad sed to disable the execution of the clone script in CMakeLists.txt
RUN ln -sf /bin/bash /usr/bin/bash && \
    sed -i 's/if((NOT WIN32/if(FALSE AND (NOT WIN32/g' CMakeLists.txt

# Run the build
RUN mkdir -p build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_VCPKG=OFF \
    -DVCPKG_TARGET_TRIPLET=x64-linux-musl \
    -DENABLE_VARIOUS=ON \
    -DENABLE_DESKTOP_NOTIFICATIONS=OFF \
    -DENABLE_BACKTRACE=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install

# --- Stage 2: Final Runtime ---
FROM alpine:latest

# Runtime dependencies
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

# Copy results
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