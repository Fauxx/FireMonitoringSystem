---
sidebar_position: 3
title: Kubernetes Manifests
---

# Kubernetes Architecture

> **STATUS: CURRENT**  
> The Kubernetes manifests actively deploy to a local Kind cluster for validation, with staging/production configurations structurally ready for the GCP/GKE migration.

## 📁 Kustomize Base & Overlay Structure

The platform uses **Kustomize** to maintain template-free declarative manifests, organized via a standard Base/Overlay pattern:

```text
infrastructure/k8s/
├── base/        # Environment-agnostic K8s resources
└── overlays/
    ├── dev/     # Staging/Dev specific patches
    ├── prod/    # Production specific patches
    └── local/   # Local Kind testing patches
```

### Base Manifests
Defines the shared, universal topologies of the workloads:
- **Stateless Apps**: `api`, `dashboard`, `etl-processor`.
- **StatefulSets**: `db` (PostgreSQL), `influx` (InfluxDB). Includes 10Gi PersistentVolumeClaim templates.
- **DaemonSets**: `alloy`, `node-exporter`, `cadvisor`.
- **Jobs**: `flyway-migrate`.

### Overlay Environments

1. **Local Overlay (`fire-monitoring-local`)**:
   - Disables image pulling (`imagePullPolicy: Never`) to use locally built Docker images.
   - Deletes the `cloudflared` deployment entirely (relies on `kubectl port-forward`).
   
2. **Dev Overlay (`fire-monitoring-dev`)**:
   - Single replica constraints.
   - Sets Cloudflare tunnel config and relaxed Ingress rules (`dev.fires.systems`).
   - Applies RBAC for team collaboration (`teammate-viewer`, `teammate-admin`).

3. **Prod Overlay (`fire-monitoring-prod`)**:
   - Scaled replicas (e.g., API and Dashboard scale to 2).
   - Enforces Let's Encrypt TLS (`cert-manager.io/cluster-issuer: letsencrypt-prod`).
   - Applies aggressive rate-limiting (50 RPS, 10 connections).
   - Routes traffic to production domains (`fires.systems`).

## 🔀 Ingress & Networking

Traffic ingress does not rely on exposing Kubernetes NodePorts directly to the public web. 

1. **Cloudflare Tunnel (`cloudflared`)**:
   - Runs as a 2-replica Deployment inside the cluster.
   - Establishes a secure, outbound-only connection to the Cloudflare Edge.
   - Proxies inbound internet traffic directly to `ingress-nginx`.
2. **Nginx Ingress Controller**:
   - Receives traffic from the tunnel.
   - Evaluates path-based routing (`/api` -> `api`, `/mqtt` -> `mqtt`, `/` -> `dashboard`).

## ⚙️ Configuration & Secrets Boundaries

- **ConfigMaps**: Constructed dynamically via `configMapGenerator` in `kustomization.yaml` (e.g., loading `mosquitto.conf`, `telegraf.conf`, and `prometheus.yml` from raw files).
- **Secrets**: Currently stubbed via `secrets.yaml.example` in overlays. Managed manually or via GitOps secrets tools in higher environments.

## 🚢 ArgoCD GitOps Reconciliation

ArgoCD is configured using the **App-of-Apps** pattern (found in `build/local/argocd-apps.yaml`). 
- ArgoCD continuously pulls the target overlay from GitHub.
- **Sync Waves**:
  - `Sync Wave 5`: The `flyway-migrate` Job executes schema changes against the PostgreSQL database.
  - `Sync Wave 10`: Only if Wave 5 succeeds, the application Pods (`api`, `dashboard`, `etl-processor`) are rolled out. This guarantees zero-downtime database migrations.
