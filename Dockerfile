FROM debian:12-slim

# 1. Install Runtime Libraries + gosu
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    gosu \
    adduser \
    libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Node.js 22 (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# 3. Download and install MEGAcmd directly from the official repo
RUN curl -o megacmd.deb https://mega.nz/linux/repo/Debian_12/amd64/megacmd-Debian_12_amd64.deb && \
    apt-get update && \
    apt-get install -y ./megacmd.deb && \
    rm megacmd.deb && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

# App Environment
ENV PORT=3000 \
    PUID=1000 \
    PGID=1000 \
    DOWNLOAD_DIR=/downloads

# Install Node dependencies
COPY package*.json ./
RUN npm ci

# Copy app code
COPY . .
RUN chmod +x entrypoint.sh && \
    mkdir -p ${DOWNLOAD_DIR}

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl --fail http://localhost:${PORT}/health || exit 1

ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]