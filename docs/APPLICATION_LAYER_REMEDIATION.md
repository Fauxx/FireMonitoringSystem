# Application Layer Troubleshooting & Remediation Plan
## Fire Monitoring System - Dashboard Content Delivery Issue

---

## EXECUTIVE SUMMARY

**Current State:** Kubernetes networking layer is healthy (200 OK responses), but the application layer is serving the Nginx default welcome page instead of the custom dashboard.

**Root Cause:** Dockerfile incorrectly copies the `public/` directory into a subdirectory rather than flattening its contents to the Nginx document root.

**Impact:** Dashboard cannot display; users see "Welcome to nginx" instead of login page.

**Timeline to Resolution:** ~15 minutes (diagnosis) + rebuild time

---

## PHASE 1: INVESTIGATION & DIAGNOSIS

### 1.1 Verify Connectivity (Baseline - Already Confirmed ✓)

```bash
# Current status: Working
kubectl port-forward -n fire-monitoring-dev svc/dashboard 8081:80 &
curl -I http://localhost:8081

# Expected output:
# HTTP/1.1 200 OK
# Server: nginx/1.29.8 (or similar)
```

**Status:** ✓ PASS - Networking layer is functional

---

### 1.2 Inspect Container Filesystem

**Objective:** Verify what files are actually in the running container

```bash
# Step 1: Find the dashboard pod
kubectl get pods -n fire-monitoring-dev | grep dashboard
# Output example: dashboard-7f8c5k9d 1/1 Running

# Step 2: Execute into the pod and list the Nginx html root
kubectl exec -it -n fire-monitoring-dev <POD_NAME> -- ls -lR /usr/share/nginx/html

# Expected if broken (current state):
# /usr/share/nginx/html:
# total 8
# drwxr-xr-x 2 root root 4096 May 11 10:30 public
# -rw-r--r-- 1 root root   17 May 11 10:30 index.html
#
# /usr/share/nginx/html/public:
# total 12
# drwxr-xr-x 2 root root 4096 May 11 10:30 css
# -rw-r--r-- 1 root root 2048 May 11 10:30 login.html
# -rw-r--r-- 1 root root 1024 May 11 10:30 signup.html
# drwxr-xr-x 3 root root 4096 May 11 10:30 protected

# Expected if fixed (target state):
# /usr/share/nginx/html:
# total 32
# drwxr-xr-x 2 root root 4096 May 11 10:30 css
# drwxr-xr-x 3 root root 4096 May 11 10:30 protected
# -rw-r--r-- 1 root root 2048 May 11 10:30 login.html
# -rw-r--r-- 1 root root 1024 May 11 10:30 signup.html
```

### 1.3 Check Nginx Configuration Inside Container

```bash
# View the active nginx.conf
kubectl exec -it -n fire-monitoring-dev <POD_NAME> -- cat /etc/nginx/nginx.conf

# View the default.conf (if it exists)
kubectl exec -it -n fire-monitoring-dev <POD_NAME> -- cat /etc/nginx/conf.d/default.conf

# Expected current behavior:
# - server_name _;
# - root /usr/share/nginx/html;
# - index index.html index.htm;
# - This serves /usr/share/nginx/html/index.html (the default Nginx page)
```

### 1.4 Verify Image Being Deployed

```bash
# Check which image is actually deployed
kubectl get deployment dashboard -n fire-monitoring-dev -o yaml | grep image:

# Expected output:
# image: ghcr.io/fauxx/firemonitoringsystem/dashboard:latest

# If you see:
# image: dashboard
# Or: image: nginx:alpine
# Then the Kustomize image substitution is not working
```

---

## PHASE 2: ROOT CAUSE ANALYSIS

### Issue #1: Dockerfile COPY Command

**Current Dockerfile (BROKEN):**
```dockerfile
FROM nginx:alpine

# Copy HTML/JS bundle
COPY public /usr/share/nginx/html

# Copy CSS bundle
COPY ./public /usr/share/nginx/html

EXPOSE 80
```

**Problems:**
1. Line 4: `COPY public /usr/share/nginx/html` creates `/usr/share/nginx/html/public/` (subdirectory)
2. Line 7: Duplicate COPY command (redundant)
3. No custom nginx.conf to handle routing or set index correctly
4. Nginx looks for `/usr/share/nginx/html/index.html` but finds nothing there

**Visual Breakdown:**
```
Host Directory: apps/dashboard/public/
├── css/
├── login.html
├── signup.html
└── protected/

CURRENT (WRONG):
Copied to: /usr/share/nginx/html/public/  ← NESTED!
Nginx looks for: /usr/share/nginx/html/index.html → NOT FOUND
Fallback: /usr/share/nginx/html/index.html → DEFAULT WELCOME PAGE ✗

EXPECTED (CORRECT):
Copied to: /usr/share/nginx/html/  ← FLATTENED!
Nginx looks for: /usr/share/nginx/html/index.html → NOT FOUND (still need custom conf)
Custom conf: try_files $uri $uri/ /login.html → SERVES login.html ✓
```

---

## PHASE 3: FIX STRATEGY

### Fix #1: Correct Dockerfile COPY Command

**Objective:** Copy the contents of `public/` directly into `/usr/share/nginx/html`

```dockerfile
# Option A: Using wildcard (recommended)
COPY public/* /usr/share/nginx/html/

# Option B: Copy entire public and then rename
COPY public/ /usr/share/nginx/html/

# Option C: Multi-stage build (advanced - not needed here)
```

### Fix #2: Add Custom Nginx Configuration

**Objective:** Configure Nginx to serve login.html as default and handle SPA routing

Create `apps/dashboard/nginx.conf`:

```nginx
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    
    # Set default index
    index login.html index.html;
    
    # Static assets - cache them
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # SPA routing - fallback to login.html for non-existent routes
    location / {
        try_files $uri $uri/ /login.html;
    }
    
    # Health check endpoint
    location /health {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
```

### Fix #3: Update Dockerfile to Use Custom Nginx Config

```dockerfile
FROM nginx:alpine

# Copy configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static files - FLATTEN the directory
COPY public/ /usr/share/nginx/html/

EXPOSE 80
```

---

## PHASE 4: IMPLEMENTATION

### Step-by-Step Fix

#### Step 4.1: Create Custom Nginx Configuration

Location: `apps/dashboard/nginx.conf`

```nginx
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index login.html index.html;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_min_length 1024;
    
    # Static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # API proxy (if needed for local dev)
    location /api {
        proxy_pass http://api:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # SPA routing
    location / {
        try_files $uri $uri/ /login.html;
    }
    
    # Health check
    location /health {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
```

#### Step 4.2: Fix Dockerfile

Location: `apps/dashboard/Dockerfile`

Replace with:

```dockerfile
# Build stage (if using a build process)
# FROM node:18-alpine as builder
# WORKDIR /app
# COPY package*.json ./
# RUN npm ci
# COPY . .
# RUN npm run build
# Adjust if you have a build step

# Serve stage
FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static files directly to root (no subdirectories)
COPY public/ /usr/share/nginx/html/

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

EXPOSE 80

# Default command (usually not needed but can be explicit)
CMD ["nginx", "-g", "daemon off;"]
```

#### Step 4.3: Rebuild and Push Docker Image

```bash
# Navigate to dashboard directory
cd apps/dashboard

# Build image
docker build -t ghcr.io/fauxx/firemonitoringsystem/dashboard:latest .

# Push to registry
docker push ghcr.io/fauxx/firemonitoringsystem/dashboard:latest

# Or using make (if available)
make build-dashboard
make push-dashboard
```

#### Step 4.4: Trigger Kubernetes Rollout

```bash
# Force pod restart to pull new image
kubectl rollout restart deployment/dashboard -n fire-monitoring-dev

# Wait for new pod to be ready
kubectl rollout status deployment/dashboard -n fire-monitoring-dev -w

# Monitor pod startup
kubectl logs -n fire-monitoring-dev -f -l app=dashboard
```

#### Step 4.5: Verify Fix

```bash
# Port forward
kubectl port-forward -n fire-monitoring-dev svc/dashboard 8081:80

# Test in terminal
curl http://localhost:8081
# Should return login.html HTML content, NOT welcome page

# Or in browser
open http://localhost:8081
# Should show login page with CSS styling
```

---

## PHASE 5: VALIDATION CHECKLIST

### Pre-Deployment Validation

- [ ] Dockerfile syntax is correct (`docker build` succeeds locally)
- [ ] `public/` directory exists and contains `login.html`, `signup.html`, `css/`, etc.
- [ ] `nginx.conf` contains proper routing rules
- [ ] Image builds successfully: `docker build -t test-dashboard .`
- [ ] Image size is reasonable (~10-20 MB, not hundreds)

### Post-Deployment Validation

- [ ] Pod starts and reaches "Running" state
- [ ] Pod doesn't crash/restart: `kubectl get pods -n fire-monitoring-dev`
- [ ] Logs show no errors: `kubectl logs -n fire-monitoring-dev -l app=dashboard`
- [ ] Container filesystem is correct: `kubectl exec -it pod -- ls /usr/share/nginx/html`
- [ ] HTTP response is 200: `curl -I http://localhost:8081`
- [ ] Response contains login.html: `curl http://localhost:8081 | head -20`
- [ ] CSS files are served: `curl http://localhost:8081/css/style.css`
- [ ] Protected pages accessible: `curl http://localhost:8081/protected/dashboard.html`

---

## PHASE 6: TROUBLESHOOTING

### If Pods Still Show Welcome Page After Fix

```bash
# Diagnostic 1: Verify image was updated
kubectl describe pod <POD_NAME> -n fire-monitoring-dev | grep Image:

# Diagnostic 2: Check if old image is cached
docker images | grep dashboard
# If old image exists, may need to specify imagePullPolicy
kubectl patch deployment dashboard -n fire-monitoring-dev -p '{"spec":{"template":{"spec":{"containers":[{"name":"dashboard","imagePullPolicy":"Always"}]}}}}'

# Diagnostic 3: Force delete pod to force pull
kubectl delete pod -n fire-monitoring-dev -l app=dashboard

# Diagnostic 4: Check registry credentials
kubectl get secret ghcr-credentials -n fire-monitoring-dev -o yaml
```

### If Container Fails to Start

```bash
# Check logs
kubectl logs -n fire-monitoring-dev -f deployment/dashboard

# Common errors:
# "exec: \"nginx\": not found" → Wrong base image or nginx not installed
# "permission denied" → File permission issues in Dockerfile
# "bind: permission denied" → Port 80 requires root (nginx:alpine runs as root, OK)

# Debug pod interactively
kubectl run -it --rm debug --image=ghcr.io/fauxx/firemonitoringsystem/dashboard:latest --restart=Never -- /bin/sh
```

### If Image Pull Fails

```bash
# Verify registry credentials
kubectl get imagepullsecrets -n fire-monitoring-dev

# Test registry access
docker login ghcr.io
docker pull ghcr.io/fauxx/firemonitoringsystem/dashboard:latest

# If credentials invalid, update secret:
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<token> \
  --docker-email=<email> \
  -n fire-monitoring-dev --dry-run=client -o yaml | kubectl apply -f -
```

---

## PHASE 7: PRODUCTION DEPLOYMENT

Once verified in dev environment, replicate the same Dockerfile changes:

```bash
# Build with prod tag
docker build -t ghcr.io/fauxx/firemonitoringsystem/dashboard:v1.0.0 .
docker push ghcr.io/fauxx/firemonitoringsystem/dashboard:v1.0.0

# Update prod overlay to use new tag
# Edit: infrastructure/k8s/overlays/prod/kustomization.yaml

# Deploy to prod
kubectl apply -k infrastructure/k8s/overlays/prod

# Verify
curl https://your-domain.com/
# Should show login page with HTTPS
```

---

## PHASE 8: DOCUMENT LESSONS LEARNED

### What Went Wrong
- Dockerfile COPY command placed files in subdirectory
- Missing nginx configuration for SPA routing
- No custom index configuration

### Prevention Measures
- [ ] Add Dockerfile linting to CI/CD pipeline
- [ ] Document expected container filesystem structure
- [ ] Add integration tests that verify web server serves correct content
- [ ] Add health check endpoint validation to deployment tests

### Updated Documentation
- [ ] Document dashboard build process in `apps/dashboard/README.md`
- [ ] Add troubleshooting section to main `DEPLOYMENT_PLAN.md`
- [ ] Create `.dockerignore` to exclude unnecessary files

---

## QUICK REFERENCE COMMANDS

### Immediate Diagnostics (Run These First)
```bash
# Check pod status
kubectl get pods -n fire-monitoring-dev -o wide

# Get dashboard pod name
DASH_POD=$(kubectl get pods -n fire-monitoring-dev -l app=dashboard -o jsonpath='{.items[0].metadata.name}')

# Check container filesystem
kubectl exec -it $DASH_POD -n fire-monitoring-dev -- ls -lR /usr/share/nginx/html

# Check which image is running
kubectl get pods $DASH_POD -n fire-monitoring-dev -o jsonpath='{.spec.containers[0].image}'

# Test content
curl http://localhost:8081 | grep -o "<title>.*</title>"
```

### Quick Fix (After Updating Files)
```bash
cd apps/dashboard
docker build -t ghcr.io/fauxx/firemonitoringsystem/dashboard:latest .
docker push ghcr.io/fauxx/firemonitoringsystem/dashboard:latest
kubectl rollout restart deployment/dashboard -n fire-monitoring-dev
kubectl rollout status deployment/dashboard -n fire-monitoring-dev -w
```

---

## SUCCESS CRITERIA

✓ Dashboard pod is running  
✓ curl returns 200 OK  
✓ Response contains `<html>` tag (not "Welcome to nginx")  
✓ CSS files load correctly (check Network tab in browser dev tools)  
✓ Login page displays with proper styling  
✓ No JavaScript errors in browser console  
✓ Telegraf agent can report dashboard as operational  

---

## RELATED ISSUES TO CONSIDER

1. **API Connectivity**: After dashboard fix, verify API routes work (`/api/...` paths)
2. **MQTT Data Display**: Ensure Telegraf data flows through to database and displays in Grafana
3. **Cross-Origin Requests**: If dashboard makes requests to API, may need CORS configuration
4. **SSL/TLS**: In production, ensure HTTPS works and certificates are valid

