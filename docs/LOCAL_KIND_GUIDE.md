# ☸️ Local Kind Kubernetes Deployment Guide

This guide provides step-by-step instructions for running the **Fire Monitoring System** locally on a **Kind (Kubernetes-in-Docker/Podman)** cluster.

---

## 📋 Prerequisites

Ensure the following tools are installed on your Linux workstation:
* **Podman** or **Docker** (`docker ps` or `podman ps`)
* **Kind** (`kind version`)
* **kubectl** (`kubectl version --client`)
* **cloudflared** (required only for staging/prod — the tunnel runs as an in-cluster pod)

---

## 🧭 SDLC Stages Overview

| Stage | Command | Access | Cloudflare Tunnel? |
| :--- | :--- | :--- | :--- |
| **1. Rapid Dev** | `make rapid-up` | `localhost:3000` / `:8000` | ❌ No |
| **2. Local Manifests** | `make local-up` | `localhost:8080` via port-forward | ❌ No |
| **3. Staging (Dev)** | `make staging-up` | `dev.fires.systems` | ✅ In-cluster pod |
| **4. Production** | `make prod-up` | `fires.systems` | ✅ In-cluster pod |

---

## 🐳 Stage 1: Rapid Dev (Docker Compose)

Quick iteration with hot-reload. No Kubernetes involved.

```bash
make rapid-up       # Start containers
make rapid-logs     # Watch logs
make rapid-down     # Tear down
```

---

## ☸️ Stage 2: Local Manifest Testing (Kind)

Test your Kubernetes manifests on a local Kind cluster. Access via port-forward only — no Cloudflare tunnel.

### Start
```bash
make local-up
```

### Access via port-forward
```bash
make local-port-forward
# → http://localhost:8080
```

### Restart after code edits
```bash
make local-restart
```

### Tail logs
```bash
make local-logs
```

### Stop
```bash
make local-down
```

---

## 🚀 Stage 3: Staging / Dev (ArgoCD + Cloudflare Tunnel)

Deploy via ArgoCD GitOps. The `dev` overlay includes an **in-cluster cloudflared pod** that automatically connects `dev.fires.systems` to your local cluster.

### First-time setup
```bash
make gitops-bootstrap    # Install ArgoCD, namespaces, secrets
make staging-up          # Deploy dev overlay via ArgoCD
```

### Daily workflow
```bash
make staging-sync        # Force ArgoCD sync after a push
make staging-watch       # Watch pods roll out
make gitops-ui           # ArgoCD dashboard → https://localhost:8443
```

### Pause / Resume (save laptop resources)
```bash
make staging-pause       # Scale down + disable auto-sync
make staging-resume      # Restore auto-sync
```

### Tear down
```bash
make staging-down
```

---

## 🔒 Stage 4: Production (ArgoCD + Cloudflare Tunnel)

Same as staging but deploys the `prod` overlay → `fires.systems`.

```bash
make prod-up             # Deploy prod overlay via ArgoCD
make prod-pause          # Scale down when not needed
make prod-resume         # Restore
make prod-down           # Tear down
```

---

## 🔧 Shared Utilities

```bash
make status              # Show nodes, pods, ArgoCD apps across all namespaces
make ci-validate         # Validate all Kustomize overlays
make clean               # Kill orphan processes, remove dangling images
```

---

## 🛠️ Troubleshooting

| Issue | Cause | Solution |
| :--- | :--- | :--- |
| `ErrImagePull` / `ImagePullBackOff` | App images missing in Kind node | Run `make kind-load` |
| `dev.fires.systems` not reachable | cloudflared pod not running in dev ns | Check `kubectl get pods -n fire-monitoring-dev -l app=cloudflared` |
| `Connection refused on :8080` | Port-forward not running | Run `make local-port-forward` |
| Cluster container stopped | Workstation rebooted or stopped | Run `make local-up` |

---

## 📁 Repository Structure Reference

* **Kind Cluster Config:** [`build/local/kind-config.yaml`](file:///home/zett/RiderProjects/FireMonitoringSystem/build/local/kind-config.yaml)
* **Local Overlay Manifests:** [`infrastructure/k8s/overlays/local`](file:///home/zett/RiderProjects/FireMonitoringSystem/infrastructure/k8s/overlays/local)
* **Dev Overlay Manifests:** [`infrastructure/k8s/overlays/dev`](file:///home/zett/RiderProjects/FireMonitoringSystem/infrastructure/k8s/overlays/dev)
* **Prod Overlay Manifests:** [`infrastructure/k8s/overlays/prod`](file:///home/zett/RiderProjects/FireMonitoringSystem/infrastructure/k8s/overlays/prod)
* **GitOps App-of-Apps (Dev):** [`build/local/argocd-apps-dev.yaml`](file:///home/zett/RiderProjects/FireMonitoringSystem/build/local/argocd-apps-dev.yaml)
* **GitOps App-of-Apps (Prod):** [`build/local/argocd-apps.yaml`](file:///home/zett/RiderProjects/FireMonitoringSystem/build/local/argocd-apps.yaml)
