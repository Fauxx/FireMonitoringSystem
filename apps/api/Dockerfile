# -------------------------------------------------------------
# Stage 1: Dependency Builder
# -------------------------------------------------------------
FROM node:22-alpine AS builder

WORKDIR /usr/src/app

# Install native compilation dependencies required for native addons (e.g., bcrypt)
RUN apk add --no-cache python3 make g++

COPY package*.json ./
RUN npm ci --omit=dev

# -------------------------------------------------------------
# Stage 2: Minimal Production Runner
# -------------------------------------------------------------
FROM node:22-alpine AS runner

WORKDIR /usr/src/app

# Apply Alpine security patches and remove npm/npx (unused in production runtime) to eliminate bundled vulnerabilities
RUN apk update && apk upgrade --no-cache \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /root/.npm

ENV NODE_ENV=production
ENV PORT=8000

# Copy installed production dependencies and application files
# Alpine node image comes pre-configured with non-root user 'node' (UID 1000)
COPY --chown=node:node --from=builder /usr/src/app/node_modules ./node_modules
COPY --chown=node:node package*.json ./
COPY --chown=node:node . .

USER node

EXPOSE 8000

CMD ["node", "src/server.js"]

LABEL org.opencontainers.image.source=https://github.com/Fauxx/FireMonitoringSystem