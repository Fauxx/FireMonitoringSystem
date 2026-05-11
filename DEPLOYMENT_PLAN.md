# Fire Monitoring System - Complete Deployment Plan

## 1. PROJECT OVERVIEW

**Fire Monitoring System** is a comprehensive IoT monitoring solution with:
- **Real-time Monitoring**: Dashboard for sensor data visualization
- **API Backend**: RESTful API for data access and analytics
- **Data Pipeline**: ETL processor for data ingestion and transformation
- **Time-series DB**: InfluxDB for metrics storage
- **Relational DB**: PostgreSQL for application data
- **Monitoring Stack**: Prometheus, Grafana, Loki, Alertmanager for observability
- **Message Broker**: MQTT for IoT device communication
- **Logging**: Loki for centralized log aggregation
- **Orchestration**: ArgoCD for GitOps CD/deployment

---

## 2. ARCHITECTURE LAYERS

### 2.1 Application Layer
```
┌──────────────────────────────────────────────────────────┐
│                    Dashboard (Web UI)                    │
│              (React/HTML + CSS + JavaScript)             │
│                   Port: 80 (ClusterIP)                   │
└──────────────────────────────────────────────────────────┘
         │
         ├─────────────────────────────┬───────────────────┤
         │                             │                   │
         ▼                             ▼                   ▼
    ┌─────────┐               ┌──────────────┐      ┌──────────────┐
    │   API   │               │  Analytics   │      │   Grafana    │
    │ Node.js │               │  (Prometheus)│      │  (Grafana)   │
    │8000/tcp │               │   9090/tcp   │      │  3000/tcp    │
    └─────────┘               └──────────────┘      └──────────────┘
         │                             │                   │
         └─────────────────────────────┴───────────────────┘
                          │
                          ▼
                    ┌───────────────┐
                    │    Ingress    │
                    │  Controller   │
                    │    (nginx)    │
                    └───────────────┘
```

### 2.2 Data Layer
```
┌─────────────────────────────────────────┐
│          ETL Processor (Python)          │
│     Ingests & transforms sensor data    │
└──────────┬──────────────────────────────┘
           │
     ┌─────┴──────┬────────────┐
     │            │            │
     ▼            ▼            ▼
┌─────────┐ ┌──────────┐ ┌──────────┐
│InfluxDB │ │PostgreSQL│ │  MQTT    │
│ Metrics │ │App Data  │ │ Broker   │
└─────────┘ └──────────┘ └──────────┘
```

### 2.3 Observability Stack
```
┌───────────────┐      ┌──────────────┐
│  Prometheus   │      │    Loki      │
│  Metrics      │      │    Logs      │
└───────┬───────┘      └──────┬───────┘
        │                     │
        └─────────┬───────────┘
                  │
                  ▼
          ┌──────────────┐
          │   Grafana    │
          │  Dashboard   │
          └──────────────┘
```

---

## 3. ENVIRONMENT-SPECIFIC SETUP

### 3.1 Development Environment

**Characteristics:**
- Local/private cluster (e.g., minikube, kind, dev k8s)
- Port forwarding for service access
- No public internet exposure
- Rapid iteration and debugging

**Deployment Command:**
```bash
kubectl apply -k infrastructure/k8s/overlays/dev
```

**Access Methods:**
```bash
# Method 1: Dashboard port forward
kubectl port-forward -n fire-monitoring-dev svc/dashboard 8080:80

# Method 2: API port forward
kubectl port-forward -n fire-monitoring-dev svc/api 8000:8000

# Method 3: Grafana monitoring
kubectl port-forward -n fire-monitoring-dev svc/grafana 3000:3000
```

**DNS (Optional):**
Add to `/etc/hosts`:
```
127.0.0.1  localhost
127.0.0.1  fire-monitoring.local
```

**Key Differences from Prod:**
- ✓ Localhost ingress rules
- ✓ CORS enabled for development
- ✓ Higher rate limits (100 req/s)
- ✓ No TLS/SSL
- ✓ Basic security headers only

---

### 3.2 Production Environment

**Characteristics:**
- Cloud-hosted Kubernetes cluster (DigitalOcean, AWS, Azure, GCP)
- Public internet access via LoadBalancer
- Automatic TLS/SSL via Let's Encrypt
- Security hardening (ModSecurity, OWASP rules)
- DNS-based access (your-domain.com)

**Prerequisites:**

1. **Own Domain Name** (update `your-domain.com` in configs)
   ```bash
   sed -i 's/your-domain.com/YOUR_DOMAIN.com/g' \
     infrastructure/k8s/overlays/prod/ingress-patch.yaml
   ```

2. **DNS Records Configured**
   ```
   A record: your-domain.com → LoadBalancer External IP
   A record: www.your-domain.com → LoadBalancer External IP
   ```

3. **Cert-Manager Installed** (for automatic TLS)
   ```bash
   helm repo add jetstack https://charts.jetstack.io
   helm install cert-manager jetstack/cert-manager \
     --namespace cert-manager \
     --create-namespace \
     --set installCRDs=true
   ```

4. **ClusterIssuer for Let's Encrypt**
   ```bash
   cat <<EOF | kubectl apply -f -
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: your-email@example.com
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - http01:
           ingress:
             class: nginx
   EOF
   ```

**Deployment Command:**
```bash
kubectl apply -k infrastructure/k8s/overlays/prod
```

**Get LoadBalancer IP:**
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

**Verify TLS Certificate:**
```bash
kubectl get certificate -n fire-monitoring-prod -w
```

**Key Differences from Dev:**
- ✓ Production domain ingress rules
- ✓ LoadBalancer service type
- ✓ Automatic TLS/SSL (Let's Encrypt)
- ✓ ModSecurity + OWASP enabled
- ✓ Strict rate limiting (50 req/s, 10 connections max)
- ✓ Network policies recommended

---

## 4. DEPLOYMENT WORKFLOW

### 4.1 Pre-Deployment Checklist

#### General
- [ ] Git repository cloned and updated
- [ ] Kubernetes cluster accessible (kubectl configured)
- [ ] All required namespaces created or allow auto-creation
- [ ] Docker images built and pushed to registry (ghcr.io)

#### Development Only
- [ ] Minikube/Kind cluster running (local dev)
- [ ] Enough resources allocated (4GB+ RAM, 2+ CPUs)

#### Production Only
- [ ] Domain name registered and DNS configured
- [ ] Cloud provider credentials configured (DigitalOcean/AWS/Azure/GCP)
- [ ] LoadBalancer support available in cluster
- [ ] Cert-manager installed and ClusterIssuer created
- [ ] Email address configured for Let's Encrypt notifications
- [ ] TLS certificate renewal will be automatic

### 4.2 Step-by-Step Deployment

#### Phase 1: Infrastructure Provisioning (Terraform)

```bash
# Navigate to environment directory
cd infrastructure/terraform/environments/dev  # or prod

# Initialize terraform
terraform init -backend-config=backend.conf

# Plan infrastructure
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Get outputs (kubeconfig, DNS, etc.)
terraform output
```

#### Phase 2: Kubernetes Application Deployment

```bash
# Set context
kubectl cluster-info
kubectl config current-context

# Create namespaces (usually auto-created by overlays)
kubectl create namespace fire-monitoring-dev   # or fire-monitoring-prod

# Apply Kustomize overlay
kubectl apply -k infrastructure/k8s/overlays/dev   # for dev
# OR
kubectl apply -k infrastructure/k8s/overlays/prod  # for prod

# Wait for deployments to be ready
kubectl rollout status deployment/api -n fire-monitoring-dev -w
kubectl rollout status deployment/dashboard -n fire-monitoring-dev -w
kubectl rollout status deployment/etl-processor -n fire-monitoring-dev -w
```

#### Phase 3: Verification

```bash
# Check all pods running
kubectl get pods -n fire-monitoring-dev

# Check services
kubectl get svc -n fire-monitoring-dev

# Check ingress
kubectl get ingress -n fire-monitoring-dev

# Test connectivity
kubectl port-forward -n fire-monitoring-dev svc/dashboard 8080:80
# Visit http://localhost:8080 in browser
```

---

## 5. NETWORKING SETUP

### 5.1 Dev Environment (Port Forwarding)

**Flow:**
```
User (localhost:8080)
    ↓
kubectl port-forward
    ↓
Ingress/Service (ClusterIP)
    ↓
Pod (dashboard:80)
```

**Setup:**
```bash
# Terminal 1: Dashboard
kubectl port-forward -n fire-monitoring-dev svc/dashboard 8080:80

# Terminal 2: API
kubectl port-forward -n fire-monitoring-dev svc/api 8000:8000

# Terminal 3: Grafana
kubectl port-forward -n fire-monitoring-dev svc/grafana 3000:3000

# Access
curl http://localhost:8080         # Dashboard
curl http://localhost:8000/api     # API
curl http://localhost:3000         # Grafana
```

### 5.2 Prod Environment (Public Access)

**Flow:**
```
User (your-domain.com:443)
    ↓
Internet (HTTPS)
    ↓
LoadBalancer (External IP)
    ↓
Ingress Controller (nginx)
    ↓
Services (ClusterIP)
    ↓
Pods
```

**Setup:**
```bash
# Get LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
# EXTERNAL-IP: 203.0.113.42

# Configure DNS A record
# your-domain.com → 203.0.113.42
# www.your-domain.com → 203.0.113.42

# Wait for certificate
kubectl get certificate -n fire-monitoring-prod -w

# Access (automatic HTTPS)
curl https://your-domain.com       # Dashboard
curl https://your-domain.com/api   # API
curl https://your-domain.com/grafana  # Grafana
```

**Nginx + Ingress Integration:**
- nginx ingress controller: Routes HTTP/HTTPS traffic based on Host/Path
- Security headers: Added via annotations
- Rate limiting: Configured per environment
- TLS termination: At ingress level

---

## 6. CONFIGURATION MANAGEMENT

### 6.1 Kustomize Overlays

**Base Configuration:**
```
infrastructure/k8s/base/
├── api/
│   ├── deployment.yaml
│   └── service.yaml
├── dashboard/
│   ├── deployment.yaml
│   └── service.yaml
├── ingress/
│   └── ingress.yaml
├── db/
├── grafana/
└── kustomization.yaml
```

**Environment Overlays:**
```
infrastructure/k8s/overlays/
├── dev/
│   ├── kustomization.yaml (adds patches + labels)
│   └── ingress-patch.yaml (localhost rules)
└── prod/
    ├── kustomization.yaml (adds patches + labels)
    ├── ingress-patch.yaml (domain rules)
    └── service-nginx-patch.yaml (LoadBalancer)
```

**Deployment:**
```bash
# Dev
kubectl apply -k infrastructure/k8s/overlays/dev

# Prod
kubectl apply -k infrastructure/k8s/overlays/prod
```

### 6.2 Configuration Hierarchy

```
1. Base (infrastructure/k8s/base/)
   ↓ (inherited by)
2. Environment Overlay (dev or prod)
   ↓ (customized by)
3. Patches (ingress-patch.yaml, service-patch.yaml)
   ↓ (image update via)
4. Kustomization (images section)
   ↓ (applied with)
5. kubectl apply
```

---

## 7. DATABASE & PERSISTENT STORAGE

### 7.1 PostgreSQL

**Purpose:** Application data (users, settings, etc.)

**Setup:**
```bash
# StatefulSet definition
kubectl get statefulset -n fire-monitoring-dev db

# Verify PVC
kubectl get pvc -n fire-monitoring-dev

# Access database
kubectl exec -it -n fire-monitoring-dev db-0 -- \
  psql -U postgres -d fire_monitoring
```

**Backup:**
```bash
kubectl exec -n fire-monitoring-dev db-0 -- \
  pg_dump -U postgres fire_monitoring > backup.sql
```

### 7.2 InfluxDB

**Purpose:** Time-series metrics from sensors

**Setup:**
```bash
kubectl get deployment -n fire-monitoring-dev influx
kubectl get svc -n fire-monitoring-dev influx
```

**Verify Data:**
```bash
kubectl port-forward -n fire-monitoring-dev svc/influx 8086:8086
# Access: http://localhost:8086
```

### 7.3 MQTT Broker

**Purpose:** Receive sensor data from IoT devices

**Setup:**
```bash
kubectl get deployment -n fire-monitoring-dev mqtt
kubectl get svc -n fire-monitoring-dev mqtt
```

**Test MQTT:**
```bash
# Port forward MQTT broker
kubectl port-forward -n fire-monitoring-dev svc/mqtt 1883:1883

# In another terminal, subscribe to topics
mosquitto_sub -h localhost -p 1883 -t "sensors/+/temp"
```

---

## 8. OBSERVABILITY & MONITORING

### 8.1 Prometheus

**Purpose:** Collect and store metrics

**Setup:**
```bash
kubectl get deployment -n fire-monitoring-dev prometheus
kubectl get svc -n fire-monitoring-dev prometheus
```

**Access UI:**
```bash
kubectl port-forward -n fire-monitoring-dev svc/prometheus 9090:9090
# http://localhost:9090
```

### 8.2 Grafana

**Purpose:** Visualize metrics from Prometheus

**Setup:**
```bash
kubectl get deployment -n fire-monitoring-dev grafana
kubectl get svc -n fire-monitoring-dev grafana
```

**Access Dashboards:**
```bash
kubectl port-forward -n fire-monitoring-dev svc/grafana 3000:3000
# http://localhost:3000 (default admin:admin)
```

### 8.3 Loki

**Purpose:** Centralized log aggregation

**Setup:**
```bash
kubectl get deployment -n fire-monitoring-dev loki
kubectl get svc -n fire-monitoring-dev loki
```

**Query Logs:**
```bash
# In Grafana, add Loki as data source
# queries can filter by pod, namespace, label, etc.
```

### 8.4 Alerting (Alertmanager)

**Setup:**
```bash
kubectl get deployment -n fire-monitoring-dev alertmanager
kubectl get svc -n fire-monitoring-dev alertmanager
```

---

## 9. CI/CD & DEPLOYMENT AUTOMATION

### 9.1 GitOps with ArgoCD

**Purpose:** Automated deployment from Git

**Setup:**
```bash
# ArgoCD deployed to argocd namespace
kubectl get deployment -n argocd argocd-server

# Get admin password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

**Access ArgoCD:**
```bash
kubectl port-forward -n argocd svc/argocd-server 8443:443
# https://localhost:8443
```

**Automated Deployment:**
- Commit to Git → ArgoCD detects change → Auto-deploys to cluster
- No manual `kubectl apply` needed in production

---

## 10. SCALING & PERFORMANCE

### 10.1 Horizontal Scaling

**Scale API Deployments:**
```bash
kubectl scale deployment api --replicas=3 -n fire-monitoring-dev
kubectl scale deployment dashboard --replicas=2 -n fire-monitoring-dev
```

**Auto-scaling (HPA - Horizontal Pod Autoscaler):**
```bash
# Create HPA for API (example)
kubectl autoscale deployment api \
  --min=2 --max=10 \
  --cpu-percent=70 \
  -n fire-monitoring-dev
```

### 10.2 Resource Requests & Limits

**Example (from deployment manifests):**
```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

Adjust based on load testing and production metrics.

---

## 11. SECURITY CONSIDERATIONS

### 11.1 Dev Environment
- ✓ No TLS (local development)
- ✓ CORS enabled for debugging
- ✓ Basic authentication (optional)
- ✓ No network policies needed

### 11.2 Prod Environment
- ✓ TLS/SSL enforced (Let's Encrypt)
- ✓ ModSecurity + OWASP rules enabled
- ✓ Rate limiting enforced
- ✓ Network policies restrict traffic
- ✓ Pod Security Policies/Standards
- ✓ RBAC for access control
- ✓ Secret management (environment variables, K8s Secrets)

**Network Policy Example:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: fire-monitoring-api
  namespace: fire-monitoring-prod
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: fire-monitoring-prod
```

---

## 12. TROUBLESHOOTING GUIDE

### 12.1 Port Forwarding Issues

**Problem:** Port already in use
```bash
# Find process using port
lsof -i :8080

# Kill process
kill -9 <PID>
```

**Problem:** Service not found
```bash
# Verify service exists
kubectl get svc -n fire-monitoring-dev dashboard

# Check service endpoints
kubectl get endpoints -n fire-monitoring-dev dashboard
```

### 12.2 Deployment Failures

**Problem:** Pods not running
```bash
# Check pod status
kubectl describe pod <pod-name> -n fire-monitoring-dev

# View logs
kubectl logs <pod-name> -n fire-monitoring-dev

# Check events
kubectl get events -n fire-monitoring-dev --sort-by='.lastTimestamp'
```

### 12.3 Ingress Not Working

**Problem:** 503 Bad Gateway
```bash
# Check ingress
kubectl describe ingress fire-monitoring -n fire-monitoring-prod

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### 12.4 Certificate Issues (Prod)

**Problem:** Certificate not issued
```bash
# Check certificate status
kubectl get certificate -n fire-monitoring-prod -o yaml

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Manual renewal
kubectl delete certificate fire-monitoring-tls -n fire-monitoring-prod
kubectl apply -k infrastructure/k8s/overlays/prod
```

---

## 13. BACKUP & DISASTER RECOVERY

### 13.1 Database Backups

**PostgreSQL Backup:**
```bash
kubectl exec -n fire-monitoring-prod db-0 -- \
  pg_dump -U postgres fire_monitoring > backup-$(date +%Y%m%d).sql

# Restore
kubectl cp backup-20240511.sql fire-monitoring-prod/db-0:/tmp/
kubectl exec -n fire-monitoring-prod db-0 -- \
  psql -U postgres < /tmp/backup-20240511.sql
```

### 13.2 Persistent Volume Snapshots

```bash
# Create snapshot (cloud provider-specific)
# Example (DigitalOcean):
doctl compute volume-snapshot create <volume-id> --snapshot-name backup-$(date +%s)
```

---

## 14. REFERENCES & RESOURCES

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Kustomize](https://kustomize.io/)
- [cert-manager](https://cert-manager.io/)
- [DigitalOcean Kubernetes Service](https://www.digitalocean.com/products/kubernetes/)
- [Terraform](https://www.terraform.io/)
- [ArgoCD](https://argoproj.github.io/argo-cd/)
- [Prometheus](https://prometheus.io/)
- [Grafana](https://grafana.com/)

---

## 15. NEXT STEPS

1. **Update Configuration Files**
   - [ ] Replace `your-domain.com` with actual domain (prod only)
   - [ ] Update email for Let's Encrypt notifications

2. **Pre-deployment Setup**
   - [ ] Configure cloud provider credentials
   - [ ] Install Terraform and Helm
   - [ ] Create DNS records (prod only)

3. **Deploy Infrastructure**
   - [ ] Run Terraform for cluster provisioning
   - [ ] Deploy Kubernetes applications with Kustomize
   - [ ] Verify all services running

4. **Post-deployment Verification**
   - [ ] Test endpoints (curl, browser)
   - [ ] Verify logs in Loki/Grafana
   - [ ] Monitor resource usage
   - [ ] Set up alerts in Alertmanager

5. **Optimization**
   - [ ] Configure auto-scaling (HPA)
   - [ ] Fine-tune resource requests/limits
   - [ ] Implement backup strategy
   - [ ] Document operational procedures
