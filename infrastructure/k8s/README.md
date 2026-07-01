# Kubernetes Manifests & GitOps Layout

This directory houses the Kubernetes resource manifests and Kustomize overlays that define the declarative state of the Fire Monitoring Platform.

---

## 📂 Layout Index

*   [**`base/`**](./base/): Defines the fundamental cluster resources (Deployments, StatefulSets, Services, Claims, DaemonSets).
    *   [**`sql/` (Flyway Migrations)**](./base/sql/): Relational database schemas and initialization scripts.
    *   [**`grafana/`**](./base/grafana/): Deployment configurations, provisioning engines, and telemetry dashboards.
    *   [**`alloy/`**](./base/alloy/): DaemonSet configurations for container log scraping.
    *   [**`prometheus/`**](./base/prometheus/): Scrape metrics definitions.
    *   [**`telegraf/`**](./base/telegraf/): Ingestion parsers for MQTT payloads.
*   [**`overlays/`**](./overlays/): Houses environment overrides configuring replica bounds, namespaces, domain configurations, and ingress settings:
    *   `dev/`: Scales down resources for development, overrides image versions with active tags, and sets namespace to `fire-monitoring-dev`.
    *   `prod/`: Adds ModSecurity annotations, sets Namespace to `fire-monitoring-prod`, and configures automated cert-manager TLS.
    *   `local/`: Compatibility overlay for local Kind execution.

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
