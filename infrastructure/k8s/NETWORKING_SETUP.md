# Fire Monitoring System - Kubernetes Networking Setup

## Architecture Overview (V2 - Cloudflare Tunnel)

This setup leverages **Cloudflare Tunnels (Zero Trust)** to completely secure the Kubernetes cluster from the public internet. We no longer use expensive Cloud LoadBalancers or manual `cert-manager` configurations, as Cloudflare handles TLS and DDoS protection automatically.

### Architecture Flow

```
┌─────────────┐
│   Internet  │
└──────┬──────┘
       │ (TLS handled by Cloudflare)
       ▼
┌─────────────────────────────────────────┐
│     Cloudflare Edge Network             │
└─────────────┬───────────────────────────┘
              │ (Secure WebSocket/HTTP Tunnel)
              ▼
┌─────────────────────────────────────────┐
│   cloudflared Pod (inside k8s cluster)  │
└─────────────┬───────────────────────────┘
              │ 
              ▼
┌─────────────────────────────────────────┐
│    Ingress Controller (nginx)           │
│  • Routing based on Host/Path           │
│  • Rate limiting / Security headers     │
└─────────────┬───────────────────────────┘
              │
     ┌────────┼────────┬────────────┐
     │        │        │            │
     ▼        ▼        ▼            ▼
 Dashboard   API   MQTT-Broker  Analytics
 (React V2) (Node) (WebSockets) (Postgres/Influx)
```

---

## 1. Cloudflare Tunnel Configuration

The tunnel is configured via the `cloudflared-config` ConfigMap (`infrastructure/k8s/base/cloudflared/configmap.yaml`). 

### Ingress Rules

The tunnel maps external hostnames directly to our internal Nginx Ingress Controller:

```yaml
ingress:
  # Main application domain → routes to Nginx Ingress
  - hostname: dev.fires.systems
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
  
  # Catch-all
  - service: http_status:404
```

*Note: The legacy `ops.dev.fires.systems` domain for Grafana has been decommissioned.*

---

## 2. Nginx Ingress Controller

While Cloudflare handles the external entry point, **Nginx Ingress** is still used internally to route traffic from `dev.fires.systems` to the correct internal pods (Dashboard vs API vs MQTT).

### Key Routing Rules

1.  **Dashboard (V2)**: Traffic to `/` routes to the React SPA container (port 8080).
2.  **API**: Traffic to `/api/*` and `/auth/*` routes to the Node.js Express backend.
3.  **MQTT WebSockets**: Traffic to `/mqtt` routes to the Mosquitto broker (port 9001) for the live React dashboard feed. *(Note: Cloudflare natively supports WebSockets without extra configuration).*

---

## 3. Local Development (Port Forwarding)

If you are developing locally without the Cloudflare Tunnel, use standard port forwarding:

```bash
# 1. Deploy the dev cluster
kubectl apply -k infrastructure/k8s/overlays/dev

# 2. Port forward the services
kubectl port-forward -n fire-monitoring-dev svc/dashboard-v2 8080:8080 &
kubectl port-forward -n fire-monitoring-dev svc/api 8000:8000 &
kubectl port-forward -n fire-monitoring-dev svc/mqtt-broker 9001:9001 &

# 3. Access locally
# Dashboard: http://localhost:8080
# API: http://localhost:8000
```

---

## 4. Decommissioned Legacy Components

The following legacy networking components have been **removed** to reduce technical debt, lower cloud costs, and improve security:

1.  **Public Cloud LoadBalancer (AWS/DO)**: Replaced entirely by Cloudflare Tunnels.
2.  **cert-manager (Let's Encrypt)**: Cloudflare provisions and manages wildcard SSL certificates automatically at the edge.
3.  **Grafana Ingress**: The ops dashboard has been replaced by the native React Dashboard. The `ops.dev.fires.systems` route is deleted.

---

## 5. Security & Rate Limiting

*   **Zero Trust**: All cluster nodes and LoadBalancers are completely hidden from the public internet. There are zero open inbound ports on the firewall.
*   **WAF (Web Application Firewall)**: Handled at the Cloudflare edge level before traffic even reaches the cluster.
*   **Rate Limiting**: Enforced both at Cloudflare and inside Nginx Ingress.
