# Serve static dashboard assets via Nginx
FROM nginx:alpine

# Copy HTML/JS bundle
COPY public /usr/share/nginx/html

# Copy CSS bundle
COPY styles /usr/share/nginx/html/styles

EXPOSE 80

