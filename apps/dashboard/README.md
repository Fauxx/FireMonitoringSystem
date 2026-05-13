# Dashboard Build & Deployment Guide

## Overview

The dashboard is a static web application served via Nginx, containing:
- Login page (login.html)
- Sign-up page (signup.html)  
- Protected dashboard views (protected/)
- Stylesheets (css/)
- Client-side JavaScript (script.js, messenger.js, etc.)

## Local Development

### Prerequisites
- Nginx installed locally (or Docker)
- Text editor for HTML/CSS/JS modifications

### Running Locally

#### Option 1: Using Docker

```bash
# Build image
docker build -t dashboard:dev .

# Run container
docker run -p 8080:80 dashboard:dev

# Access
open http://localhost:8080
```

#### Option 2: Using Local Nginx

```bash
# Copy public files to nginx html directory (macOS)
sudo cp -r public/* /usr/local/var/www

# Or create a vhost config pointing to public/
# Then access http://localhost:8080
```

## Docker Build Process

### Dockerfile Structure

```dockerfile
FROM nginx:alpine                              # Base image: lightweight nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf # Custom nginx config
COPY public/ /usr/share/nginx/html/           # Copy files to web root
HEALTHCHECK ...                                # Kubernetes health probe
CMD ["nginx", "-g", "daemon off;"]            # Run nginx in foreground
```

### Key Implementation Details

1. **public/ Directory**: Contains all static assets
   - Must be copied with trailing slash: `COPY public/` to flatten contents
   - Results in: `/usr/share/nginx/html/css/`, `/usr/share/nginx/html/login.html`, etc.

2. **nginx.conf**: Custom configuration
   - Sets `index login.html;` as default file
   - Implements SPA routing: `try_files $uri $uri/ /login.html;`
   - Proxies /api requests to backend service
   - Adds security headers
   - Enables gzip compression

3. **HEALTHCHECK**: Kubernetes readiness probe
   - Verifies pod is healthy before receiving traffic
   - Checks `/health` endpoint

## Building & Pushing

### Build Locally

```bash
# Navigate to dashboard directory
cd apps/dashboard

# Build image
docker build -t ghcr.io/fauxx/firemonitoringsystem/dashboard:latest .

# Or with specific tag
docker build -t ghcr.io/fauxx/firemonitoringsystem/dashboard:v1.0.0 .
```

### Test Locally

```bash
# Run and test
docker run -p 8080:80 ghcr.io/fauxx/firemonitoringsystem/dashboard:latest

# In another terminal:
curl http://localhost:8080/
# Should return login.html content, not "Welcome to nginx"

curl http://localhost:8080/health
# Should return: OK

curl http://localhost:8080/css/style.css
# Should return CSS content with 200 OK
```

### Push to Registry

```bash
# Authenticate with GitHub Container Registry
echo $GHCR_TOKEN | docker login ghcr.io -u <username> --password-stdin

# Push image
docker push ghcr.io/fauxx/firemonitoringsystem/dashboard:latest

# Or using alternative registries (Docker Hub, AWS ECR, etc.)
```

## Kubernetes Deployment

### Image Configuration

The Kustomize overlays handle image substitution:

```yaml
# infrastructure/k8s/overlays/dev/kustomization.yaml
images:
  - name: dashboard
    newName: ghcr.io/fauxx/firemonitoringsystem/dashboard
    newTag: latest
```

### Deploy to Cluster

```bash
# Dev environment (port-forward)
kubectl apply -k infrastructure/k8s/overlays/dev

# Verify deployment
kubectl get pods -n fire-monitoring-dev -l app=dashboard
kubectl logs -n fire-monitoring-dev -l app=dashboard

# Port forward to test
kubectl port-forward -n fire-monitoring-dev svc/dashboard 8080:80
# http://localhost:8080
```

### Verify Pod is Healthy

```bash
# Check pod status
kubectl get pods -n fire-monitoring-dev | grep dashboard
# Status should be: 1/1 Running

# Check events
kubectl describe pod <pod-name> -n fire-monitoring-dev

# Check logs
kubectl logs -n fire-monitoring-dev <pod-name>

# Check health endpoint
kubectl exec -it -n fire-monitoring-dev <pod-name> -- wget -q -O - http://localhost/health
# Should output: OK
```

## Troubleshooting

### Issue: "Welcome to nginx" Instead of Login Page

**Cause:** Files not in correct location in container

**Fix:**
1. Verify Dockerfile has `COPY public/` (with trailing slash)
2. Check container filesystem: 
   ```bash
   kubectl exec -it <pod> -n fire-monitoring-dev -- ls -la /usr/share/nginx/html
   # Should show: css, login.html, signup.html, protected (NOT a public/ subdirectory)
   ```
3. Rebuild and redeploy image

### Issue: CSS Not Loading

**Cause:** Incorrect path or permission issues

**Fix:**
1. Check CSS file exists:
   ```bash
   kubectl exec -it <pod> -n fire-monitoring-dev -- ls /usr/share/nginx/html/css/
   ```
2. Verify nginx config routing:
   ```bash
   kubectl exec -it <pod> -n fire-monitoring-dev -- cat /etc/nginx/conf.d/default.conf | grep "location"
   ```
3. Check browser dev tools Network tab for 404 errors

### Issue: API Routes Not Working (/api/...)

**Cause:** API service not running or incorrect proxy configuration

**Fix:**
1. Verify API service exists:
   ```bash
   kubectl get svc -n fire-monitoring-dev api
   ```
2. Check nginx proxy config:
   ```bash
   kubectl exec -it <pod> -n fire-monitoring-dev -- cat /etc/nginx/conf.d/default.conf | grep -A 10 "location /api"
   ```
3. Test connection from pod:
   ```bash
   kubectl exec -it <pod> -n fire-monitoring-dev -- wget -q -O - http://api:8000/health
   ```

## Performance Optimization

### Gzip Compression

Nginx is configured to compress responses:
- Enabled for text, CSS, JavaScript, SVG, fonts
- Minimum 1KB before compression

Verify:
```bash
curl -I -H "Accept-Encoding: gzip" http://localhost:8080/
# Look for: Content-Encoding: gzip
```

### Cache Headers

Static assets get 30-day cache:
- Images, CSS, JS, fonts cached with `Cache-Control: public, immutable`
- Reduces bandwidth and improves load times

Verify:
```bash
curl -I http://localhost:8080/css/style.css
# Look for: Cache-Control: public, immutable
#           Expires: [date 30 days in future]
```

## Security Considerations

### HTTPS (Production)

The dashboard is served over HTTP by the pod, but HTTPS is handled at the Ingress level:
- Kubernetes Ingress Controller terminates TLS
- Pod communicates internally via HTTP (ClusterIP only)
- No SSL certificate needed inside pod

### Security Headers

Nginx adds these headers:
```
X-Frame-Options: SAMEORIGIN              # Prevent clickjacking
X-Content-Type-Options: nosniff          # Prevent MIME sniffing
X-XSS-Protection: 1; mode=block          # XSS protection
Referrer-Policy: strict-origin-...       # Control referrer info
Permissions-Policy: ...                  # Disable sensitive APIs
```

### File Access Control

Nginx denies access to:
- Hidden files (.) 
- Backup files (~)
- Sensitive extensions configured in nginx.conf

## File Structure

```
apps/dashboard/
├── Dockerfile              # Multi-stage container definition
├── nginx.conf              # Custom nginx server configuration
├── .dockerignore           # Files excluded from build context
├── README.md               # This file
└── public/
    ├── login.html          # Login page (default)
    ├── signup.html         # Sign-up page
    ├── css/
    │   └── style.css       # Main stylesheet
    ├── protected/
    │   ├── dashboard.html  # Main dashboard
    │   ├── devices.html    # Device management
    │   ├── analytics.html  # Analytics view
    │   ├── settings.html   # User settings
    │   ├── export.html     # Export functionality
    │   ├── incident-logs.html   # Incident logs
    │   ├── sms-messages.html    # SMS messaging
    │   ├── system-analytics.html # System metrics
    │   ├── navbar.html     # Navigation component
    │   ├── script.js       # Dashboard logic
    │   ├── settings.js     # Settings logic
    │   └── messenger.js    # Messaging logic
```

## Related Documentation

- [Application Layer Remediation Plan](../../APPLICATION_LAYER_REMEDIATION.md)
- [Kubernetes Networking Setup](../../infrastructure/k8s/NETWORKING_SETUP.md)
- [Deployment Plan](../../DEPLOYMENT_PLAN.md)
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
