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

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]