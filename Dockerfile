FROM danielquinn/megacmd-alpine:latest

# Install dependencies
RUN apk add --no-cache nodejs npm su-exec shadow

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
  CMD curl --fail http://localhost:${PORT}/ || exit 1

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]