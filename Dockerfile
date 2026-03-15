FROM danielquinn/megacmd-alpine:latest

# Install Node.js, NPM, su-exec, and shadow tools
RUN apk add --no-cache nodejs npm su-exec shadow

WORKDIR /usr/src/app

# Install dependencies
COPY package*.json ./
RUN npm install --production

# Copy application code and entrypoint
COPY . .
RUN chmod +x entrypoint.sh

# Environment defaults
ENV PORT=3000
ENV HOST=0.0.0.0
ENV PUID=100
ENV PGID=100

EXPOSE 3000

# Use the entrypoint script to set up permissions, then run node
ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]
