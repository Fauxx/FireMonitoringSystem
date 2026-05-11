# Application Layer Fix - Quick Action Plan

## Current Status: 🔴 CRITICAL

**Symptom:** Dashboard pod returns HTTP 200 OK but serves Nginx default welcome page instead of login.html

**Root Cause:** Dockerfile `COPY public` instruction places files in subdirectory instead of flattening to Nginx root

**Impact:** Users cannot access dashboard; shows "Welcome to nginx"

**Timeline:** ~20-30 minutes to fix (including rebuild time)

---

## ✅ COMPLETED FIXES

The following files have been created and fixed:

### 1. ✓ Created Custom Nginx Configuration
**File:** `apps/dashboard/nginx.conf`
- Sets index to `login.html`
- Implements SPA routing fallback
- Proxies /api requests to backend
- Adds security headers
- Enables gzip compression

### 2. ✓ Fixed Dockerfile
**File:** `apps/dashboard/Dockerfile`
- **Before:** `COPY public /usr/share/nginx/html` (creates subdirectory)
- **After:** `COPY public/ /usr/share/nginx/html/` (flattens contents)
- Imports custom nginx.conf
- Adds health check

### 3. ✓ Added Docker Best Practices
**File:** `apps/dashboard/.dockerignore`
- Excludes unnecessary files from build context
- Reduces image size

### 4. ✓ Documented Build Process
**File:** `apps/dashboard/README.md`
- Local development guide
- Docker build instructions
- Troubleshooting procedures
- Performance optimization
- Security considerations

### 5. ✓ Created Comprehensive Troubleshooting Guide
**File:** `APPLICATION_LAYER_REMEDIATION.md`
- Investigation procedures
- Root cause analysis
- Implementation steps
- Validation checklist
- Troubleshooting commands

---

## 📋 NEXT STEPS - EXECUTE IN ORDER

### Step 1: Verify Fixes Were Applied

```bash
cd /home/zett/RiderProjects/FireMonitoringSystem

# Verify files exist
ls -lh apps/dashboard/Dockerfile
ls -lh apps/dashboard/nginx.conf
cat apps/dashboard/Dockerfile | head -20
```

**Expected Output:** Should show updated Dockerfile with `COPY public/` (with trailing slash)

---

### Step 2: Build Docker Image

```bash
cd apps/dashboard

# Build image with correct tag
docker build -t ghcr.io/fauxx/firemonitoringsystem/dashboard:latest .

# Verify build succeeded
echo $?  # Should be 0
docker images | grep dashboard
```

**Expected Output:** 
- Build completes without errors
- Image size ~10-20 MB (not huge)
- `docker images` shows the image

---

### Step 3: Test Image Locally

```bash
# Run container
docker run -p 8080:80 ghcr.io/fauxx/firemonitoringsystem/dashboard:latest &

# Give it 2 seconds to start
sleep 2

# Test 1: Check for login.html (NOT "Welcome to nginx")
curl http://localhost:8080 | grep -q "login" && echo "✓ SUCCESS: login.html found" || echo "✗ FAIL: Still showing default page"

# Test 2: Check health endpoint
curl http://localhost:8080/health | grep -q "OK" && echo "✓ SUCCESS: Health check passes" || echo "✗ FAIL: Health check fails"

# Test 3: Check CSS loads
curl http://localhost:8080/css/style.css | head -5

# Stop container
pkill -f "docker run"
```

**Expected Output:**
```
✓ SUCCESS: login.html found
✓ SUCCESS: Health check passes
(CSS content from style.css)
```

---

### Step 4: Push Image to Registry

```bash
# Authenticate with GitHub Container Registry (if not already)
# Replace <token> with your GitHub PAT token
echo "<token>" | docker login ghcr.io -u <github_username> --password-stdin

# Push image
docker push ghcr.io/fauxx/firemonitoringsystem/dashboard:latest

# Verify push succeeded
# Check at: https://github.com/<org>/FireMonitoringSystem/pkgs/container/firemonitoringsystem%2Fdashboard
```

**Expected Output:**
- "Pushed successfully" messages
- Image appears in GitHub Container Registry

---

### Step 5: Update Kubernetes Deployment

```bash
# Force pod restart to pull new image
kubectl rollout restart deployment/dashboard -n fire-monitoring-dev

# Watch the rollout
kubectl rollout status deployment/dashboard -n fire-monitoring-dev -w

# Wait ~30 seconds for new pod to start
```

**Expected Output:**
- Old pod terminates
- New pod starts
- Status shows: `deployment "dashboard" successfully rolled out`

---

### Step 6: Verify Pod is Running

```bash
# Get pod name
DASH_POD=$(kubectl get pods -n fire-monitoring-dev -l app=dashboard -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $DASH_POD"

# Check pod status
kubectl get pods -n fire-monitoring-dev | grep dashboard
# Should show: 1/1 Running

# Check logs (should show nginx startup, no errors)
kubectl logs -n fire-monitoring-dev $DASH_POD | head -20
```

**Expected Output:**
```
dashboard-xxxxx 1/1 Running 0 2m
(nginx startup logs - no error messages)
```

---

### Step 7: Verify Container Filesystem

```bash
# Get pod name
DASH_POD=$(kubectl get pods -n fire-monitoring-dev -l app=dashboard -o jsonpath='{.items[0].metadata.name}')

# List nginx html directory
kubectl exec -it -n fire-monitoring-dev $DASH_POD -- ls -lR /usr/share/nginx/html

# Should show:
# /usr/share/nginx/html:
# (Files directly here, NOT in a public/ subdirectory)
# css/
# login.html
# signup.html
# protected/
```

**Expected Output:** Files are in `/usr/share/nginx/html`, NOT `/usr/share/nginx/html/public/`

---

### Step 8: Test Dashboard via Port Forward

```bash
# Port forward
kubectl port-forward -n fire-monitoring-dev svc/dashboard 8081:80 &

# Wait 2 seconds
sleep 2

# Test 1: HTTP response
curl -I http://localhost:8081
# Should show: HTTP/1.1 200 OK

# Test 2: Content check
curl http://localhost:8081 | grep -E "<title>|<h1>" | head -5
# Should show HTML from login.html, NOT "Welcome to nginx"

# Test 3: CSS loads
curl -I http://localhost:8081/css/style.css
# Should show: HTTP/1.1 200 OK

# Test 4: Health endpoint
curl http://localhost:8081/health
# Should show: OK

# Stop port forward
pkill -f "kubectl port-forward"
```

**Expected Output:**
```
HTTP/1.1 200 OK Server: nginx/1.29.8
(login.html content)
HTTP/1.1 200 OK
OK
```

---

### Step 9: Test in Browser (Optional)

```bash
# Port forward again
kubectl port-forward -n fire-monitoring-dev svc/dashboard 8081:80 &

# Open browser
open http://localhost:8081    # macOS
xdg-open http://localhost:8081 # Linux
start http://localhost:8081    # Windows

# Verify:
# ✓ Login page displays (not "Welcome to nginx")
# ✓ CSS styling is applied (not plain HTML)
# ✓ Form inputs visible
# ✓ No console errors (F12 → Console tab)

# Stop port forward
pkill -f "kubectl port-forward"
```

---

## ✅ SUCCESS CRITERIA

- [ ] Docker build completes without errors
- [ ] Local Docker test shows login.html (not welcome page)
- [ ] Image pushed to registry successfully
- [ ] Kubernetes pod starts and shows "1/1 Running"
- [ ] kubectl logs show no errors
- [ ] Container filesystem shows files in root (not in public/ subdirectory)
- [ ] curl returns 200 OK
- [ ] curl response contains login.html content
- [ ] CSS files load (200 OK)
- [ ] Health endpoint responds with "OK"
- [ ] Browser shows login page with proper styling

---

## 🐛 TROUBLESHOOTING

### If Tests Still Fail

#### Scenario 1: "Welcome to nginx" Still Showing

```bash
# Check if files are in subdirectory (WRONG)
kubectl exec -it -n fire-monitoring-dev <POD> -- ls /usr/share/nginx/html/public/
# If this has files, it's wrong. Rebuild with `COPY public/` (note the slash)

# Check if Dockerfile was actually updated
cat apps/dashboard/Dockerfile | grep "COPY public"
# Should show: COPY public/ /usr/share/nginx/html/
```

**Fix:** Re-verify Dockerfile has trailing slash, rebuild, re-push, restart pod

#### Scenario 2: Pod Won't Start

```bash
# Check pod logs
kubectl logs -n fire-monitoring-dev <POD>

# Common errors:
# - "nginx: [emerg] unexpected end of file" → nginx.conf syntax error
# - "permission denied" → File permissions issue
# - "connection refused" → Port already in use

# If syntax error, validate nginx.conf locally:
docker run -it --rm -v $(pwd)/apps/dashboard/nginx.conf:/etc/nginx/conf.d/test.conf nginx:alpine nginx -t -c /etc/nginx/conf.d/test.conf
```

**Fix:** Check nginx.conf for syntax errors, rebuild

#### Scenario 3: Image Pull Fails

```bash
# Check registry credentials
kubectl get secret ghcr-credentials -n fire-monitoring-dev -o yaml | grep docker-server

# Test manual pull
kubectl run -it --rm debug --image=ghcr.io/fauxx/firemonitoringsystem/dashboard:latest --restart=Never -- /bin/sh
# If it pulls successfully, the image is fine

# If authentication fails:
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=<USERNAME> \
  --docker-password=<TOKEN> \
  -n fire-monitoring-dev --dry-run=client -o yaml | kubectl apply -f -
```

**Fix:** Update registry credentials, restart pod

---

## 📊 MONITORING AFTER FIX

### Check Dashboard is Healthy

```bash
# 1. Pod running
kubectl get pods -n fire-monitoring-dev -l app=dashboard

# 2. Service active
kubectl get svc -n fire-monitoring-dev dashboard

# 3. No restarts
kubectl describe pod -n fire-monitoring-dev -l app=dashboard | grep Restart

# 4. Ingress routing
kubectl get ingress -n fire-monitoring-dev

# 5. Monitor logs (real-time)
kubectl logs -n fire-monitoring-dev -f -l app=dashboard --all-containers=true
```

---

## 🚀 NEXT: PRODUCTION DEPLOYMENT

After verifying in dev, deploy to prod:

```bash
# 1. Update prod image tag (optional, for version control)
# Edit: infrastructure/k8s/overlays/prod/kustomization.yaml
# Change: newTag: v1.0.0 (or keep as latest)

# 2. Deploy to prod
kubectl apply -k infrastructure/k8s/overlays/prod

# 3. Verify prod deployment
kubectl get pods -n fire-monitoring-prod -l app=dashboard
kubectl port-forward -n fire-monitoring-prod svc/dashboard 8081:80
curl https://your-domain.com/
```

---

## 📚 REFERENCE DOCUMENTS

- **Detailed Guide:** [APPLICATION_LAYER_REMEDIATION.md](APPLICATION_LAYER_REMEDIATION.md)
- **Build Guide:** [apps/dashboard/README.md](apps/dashboard/README.md)
- **Networking Setup:** [infrastructure/k8s/NETWORKING_SETUP.md](infrastructure/k8s/NETWORKING_SETUP.md)
- **Full Deployment:** [DEPLOYMENT_PLAN.md](DEPLOYMENT_PLAN.md)

---

## ⏱️ ESTIMATED TIME

- Build Docker image: 2-5 minutes
- Push to registry: 1-2 minutes
- Kubernetes rollout: 30 seconds
- Testing: 5 minutes
- **Total: 10-15 minutes**

---

## ✉️ SUPPORT

If you encounter issues:

1. Check [Troubleshooting](#-troubleshooting) section above
2. Review detailed guide: `APPLICATION_LAYER_REMEDIATION.md`
3. Check logs: `kubectl logs -n fire-monitoring-dev -f -l app=dashboard`
4. Review build: `docker logs <container-id>`

Good luck! 🚀
