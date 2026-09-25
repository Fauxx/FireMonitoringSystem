# Stage: Build dashboard assets (if needed)
# FROM node:18-alpine as builder
# WORKDIR /app
# COPY package*.json ./
# RUN npm ci
# COPY . .
# RUN npm run build
# (Uncomment if you have a build process)

# Stage: Serve static dashboard assets via Nginx
FROM nginx:alpine

# Patch HIGH vulnerability in libexpat (CVE-2026-93990)
USER root
RUN apk upgrade --no-cache

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static files directly to root (flatten the directory)
COPY public/ /usr/share/nginx/html/

# Create directory for logs
RUN mkdir -p /var/log/nginx

# Security: Run Nginx as non-root
RUN chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx/conf.d \
    && touch /var/run/nginx.pid && chown nginx:nginx /var/run/nginx.pid
USER nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://127.0.0.1/health || exit 1

EXPOSE 80

# Run nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
