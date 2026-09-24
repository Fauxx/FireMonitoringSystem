# Production-ready Dockerfile for Node.js app
FROM node:22-alpine

# Create app directory
WORKDIR /usr/src/app

# Upgrade Alpine packages to fix vulnerabilities
RUN apk upgrade --no-cache

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy app source
COPY . .

# Ensure non-root user (recommended)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Expose application port
EXPOSE 8000

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8000/health || exit 1

CMD [ "node", "src/server.js" ]
