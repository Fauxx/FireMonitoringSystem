# Kubernetes Manifests & GitOps Layout

This directory houses the Kubernetes resource manifests and Kustomize overlays that define the declarative state of the Fire Monitoring Platform.

---

## 📂 Layout Index

*   [**`base/`**](./base/): Defines the fundamental cluster resources partitioned by architectural domains:
    *   [`apps/`](./base/apps/): Core microservices (`api`, `dashboard`, `etl`, `simulator`, `flyway`).
    *   [`data/`](./base/data/): In-cluster state and messaging (`influx`, `mqtt`, `telegraf`).
    *   [`observability/`](./base/observability/): Complete metrics & log collection suite (`prometheus`, `loki`, `alloy`, `cadvisor`, `node-exporter`).
    *   [`networking/`](./base/networking/): Edge ingress rules and tunnel gateways (`ingress`, `cloudflared`).
*   [**`overlays/`**](./overlays/): Houses environment-specific overrides configuring replicas, namespaces, domains, and patches:
    *   `dev/`: Development environment (`fire-monitoring-dev`), targeting `dev.fires.systems`.
    *   `prod/`: Production environment (`fire-monitoring-prod`), targeting `fires.systems`.
    *   `local/`: Compatibility overlay for local Kind execution (includes local Postgres).

---

## 🔌 Core Networking & TLS Setup

For a deep-dive on port-forwarding methods, local hosts mapping, and Let's Encrypt cluster issuers:
*   [**Networking Setup & Troubleshooting Runbook 📖**](./NETWORKING_SETUP.md)

---

## 🔄 Deployment Execution

To deploy the overlays manually using Kustomize:
```bash
# Apply development resources
kubectl apply -k infrastructure/k8s/overlays/dev

# Apply production resources
kubectl apply -k infrastructure/k8s/overlays/prod
```
The active images are compiled and pushed via GitHub Actions, which submits automated PRs updating the overlay tags. ArgoCD monitors this repository and performs automated reconciliations.
