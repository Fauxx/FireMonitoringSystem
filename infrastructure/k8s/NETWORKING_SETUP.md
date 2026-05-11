# Fire Monitoring System - Kubernetes Networking Setup

## Architecture Overview

This setup provides environment-specific networking for dev and production deployments while leveraging the nginx ingress controller for routing and security.

### Environment Comparison

| Feature | Dev | Prod |
|---------|-----|------|
| **Access Method** | Port Forwarding / Localhost | Public LoadBalancer |
| **Service Type** | ClusterIP | ClusterIP (via Ingress) |
| **Ingress** | localhost, fire-monitoring.local | your-domain.com, www.your-domain.com |
| **TLS/SSL** | None (development) | Let's Encrypt (automatic) |
| **Rate Limiting** | 100 req/s | 50 req/s |
| **Security Modules** | Basic | ModSecurity + OWASP |
| **Access Control** | Internal only | Public internet |

---

## Dev Environment Setup

### Deployment

```bash
kubectl apply -k infrastructure/k8s/overlays/dev
```

### Port Forwarding (3 methods)

#### Method 1: Direct Dashboard Port Forward
```bash
kubectl port-forward -n fire-monitoring-dev svc/dashboard 8080:80
# Access: http://localhost:8080
```

#### Method 2: Direct API Port Forward
```bash
kubectl port-forward -n fire-monitoring-dev svc/api 8000:8000
# Access: http://localhost:8000/api
```

#### Method 3: Via Ingress Pod (Recommended)
```bash
# Find the ingress controller pod
kubectl get pods -n ingress-nginx
kubectl port-forward -n ingress-nginx <pod-name> 8080:80
# Access: http://localhost:8080
# Resolve localhost to fire-monitoring.local in /etc/hosts or use localhost directly
```

#### Method 4: Using kubectl port-forward with multiple services
```bash
# Terminal 1: Dashboard
kubectl port-forward -n fire-monitoring-dev svc/dashboard 80:80

# Terminal 2: API
kubectl port-forward -n fire-monitoring-dev svc/api 8000:8000

# Terminal 3: Grafana
kubectl port-forward -n fire-monitoring-dev svc/grafana 3000:3000
```

### DNS Resolution (Optional)

Add to `/etc/hosts`:
```
127.0.0.1  localhost
127.0.0.1  fire-monitoring.local
127.0.0.1  localhost.local
```

### Local Development Workflow

```bash
# 1. Deploy to dev cluster
kubectl apply -k infrastructure/k8s/overlays/dev

# 2. Port forward services
kubectl port-forward -n fire-monitoring-dev svc/dashboard 8080:80 &
kubectl port-forward -n fire-monitoring-dev svc/api 8000:8000 &

# 3. Access locally
# Dashboard: http://localhost:8080
# API: http://localhost:8000
# Grafana: kubectl port-forward -n fire-monitoring-dev svc/grafana 3000:3000

# 4. View logs
kubectl logs -n fire-monitoring-dev -f deployment/api
kubectl logs -n fire-monitoring-dev -f deployment/dashboard

# 5. Clean up
pkill -f "kubectl port-forward"
```

---

## Production Environment Setup

### Prerequisites

1. **Domain Name**: Ensure you own `your-domain.com` and have DNS access
2. **Load Balancer**: Your Kubernetes cluster must support LoadBalancer service type (DigitalOcean, AWS, Azure, GCP, etc.)
3. **DNS Configured**: Point your domain's A record to the LoadBalancer's external IP
4. **Cert Manager**: Install cert-manager for automated TLS

#### Install Cert-Manager (if not already installed)

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true
```

#### Create ClusterIssuer for Let's Encrypt

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

### Configuration

Before deploying, update production domain in your-domain.com references:

```bash
# Update the prod ingress patch
sed -i 's/your-domain.com/YOUR_ACTUAL_DOMAIN.com/g' \
  infrastructure/k8s/overlays/prod/ingress-patch.yaml

# Or manually edit
vi infrastructure/k8s/overlays/prod/ingress-patch.yaml
```

### Deployment

```bash
# 1. Deploy to prod cluster
kubectl apply -k infrastructure/k8s/overlays/prod

# 2. Get LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# 3. Update DNS to point to LoadBalancer IP (if not auto-configured)
# your-domain.com A record → <EXTERNAL-IP>

# 4. Wait for certificate to be issued
kubectl get certificate -n fire-monitoring-prod -w

# 5. Verify ingress
kubectl get ingress -n fire-monitoring-prod
kubectl describe ingress fire-monitoring -n fire-monitoring-prod
```

### Post-Deployment Verification

```bash
# Check TLS certificate status
kubectl get certificate -n fire-monitoring-prod fire-monitoring-tls -o yaml | grep -A 5 status

# Verify HTTPS access
curl -I https://your-domain.com
curl -I https://www.your-domain.com

# Check ingress routing
curl -H "Host: your-domain.com" https://<EXTERNAL-IP>/

# Monitor ingress controller logs
kubectl logs -n ingress-nginx -f -l app.kubernetes.io/name=ingress-nginx
```

---

## Nginx & Ingress Integration

### Architecture

```
┌─────────────┐
│   Internet  │
└──────┬──────┘
       │ (public traffic)
       ▼
┌─────────────────────────────────────────┐
│    Ingress Controller (nginx)            │
│  • Routing based on Host/Path            │
│  • TLS termination                       │
│  • Rate limiting                         │
│  • Security headers                      │
└─────────────┬───────────────────────────┘
              │
     ┌────────┼────────┬────────────┐
     │        │        │            │
     ▼        ▼        ▼            ▼
 Dashboard   API    Grafana    Analytics
 (ClusterIP) (ClusterIP) (ClusterIP) (ClusterIP)
```

### How They Work Together

1. **Ingress Controller**: Listens on ports 80/443, routes traffic based on Host/Path rules
2. **Services**: Internal ClusterIP services route traffic to pods
3. **Nginx Config**: Security headers, compression, logging configured via annotations

### Key Annotations

- `kubernetes.io/ingress.class: nginx` - Use nginx controller
- `nginx.ingress.kubernetes.io/rewrite-target: /` - Path rewriting
- `nginx.ingress.kubernetes.io/limit-rps: 50` - Rate limiting
- `nginx.ingress.kubernetes.io/enable-modsecurity: "true"` - WAF protection (prod)
- `cert-manager.io/cluster-issuer: "letsencrypt-prod"` - Automatic TLS (prod)

---

## Troubleshooting

### Port Forward Not Working

```bash
# Check if service exists
kubectl get svc -n fire-monitoring-dev

# Check service endpoints
kubectl get endpoints -n fire-monitoring-dev

# Try with explicit port
kubectl port-forward -n fire-monitoring-dev svc/dashboard 127.0.0.1:8080:80
```

### Ingress Not Routing Traffic

```bash
# Check ingress exists
kubectl get ingress -n fire-monitoring-prod

# Check ingress details
kubectl describe ingress fire-monitoring -n fire-monitoring-prod

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx | tail -50

# Check if ingress controller is running
kubectl get pods -n ingress-nginx
```

### Certificate Not Issued

```bash
# Check certificate status
kubectl get certificate -n fire-monitoring-prod -o yaml

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager | tail -50

# Manually renew
kubectl delete certificate fire-monitoring-tls -n fire-monitoring-prod
kubectl apply -k infrastructure/k8s/overlays/prod
```

### DNS Not Resolving

```bash
# Check A record
nslookup your-domain.com
dig your-domain.com

# Force DNS refresh (macOS)
sudo dscacheutil -flushcache

# Check LoadBalancer IP
kubectl get svc -n ingress-nginx

# Ensure A record points to LoadBalancer external IP
```

---

## Monitoring & Logging

### View Ingress Logs

```bash
# Nginx controller logs
kubectl logs -n ingress-nginx -f -l app.kubernetes.io/name=ingress-nginx

# Filter for specific domain
kubectl logs -n ingress-nginx -f -l app.kubernetes.io/name=ingress-nginx | grep your-domain.com
```

### Monitor Rate Limiting

```bash
# Check rate limit status
kubectl logs -n ingress-nginx -f -l app.kubernetes.io/name=ingress-nginx | grep "limiting requests"
```

### Certificate Monitoring

```bash
# Watch certificate renewal
kubectl get certificate -n fire-monitoring-prod -w

# Check certificate details
kubectl get secret fire-monitoring-tls -n fire-monitoring-prod -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

---

## Security Considerations

### Dev Environment
- No TLS (http only) - suitable for development
- CORS enabled for localhost origins
- Higher rate limits for flexibility
- No ModSecurity (WAF)

### Prod Environment
- Automatic TLS via Let's Encrypt
- Rate limiting enforced (50 req/s, max 10 connections)
- ModSecurity + OWASP Core Rule Set enabled
- Network policies recommended (see k8s/base/argocd/networkpolicy.yaml)

### Network Policies

Apply network policies to restrict traffic:

```bash
# View existing policy
cat infrastructure/k8s/base/argocd/networkpolicy.yaml

# Create similar policies for your apps
kubectl create networkpolicy fire-monitoring-api \
  -n fire-monitoring-prod \
  --ingress-from namespaceSelector=matchLabels=name=fire-monitoring-prod
```

---

## References

- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Cert Manager](https://cert-manager.io/)
- [Port Forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)
