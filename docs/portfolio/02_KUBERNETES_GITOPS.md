# Kubernetes & GitOps Reconciliation

The FireMonitoringSystem leverages **GitOps** principles to ensure that the actual state of the Kubernetes cluster always matches the desired state defined in the repository.

## 🎛️ Configuration Management: Kustomize

Instead of complex Helm charts for the application layer, the project uses **Kustomize**. This allows for a clean `base` configuration with environment-specific `overlays` (e.g., `dev`, `prod`).

- **`base/`**: Contains the primary deployments, services, and default ConfigMaps for the entire stack.
- **`overlays/dev/`**:
    - Overrides image tags with specific Git SHAs via the CI pipeline.
    - Sets the `fire-monitoring-dev` namespace.
    - Scales down resources for cost-efficiency in development.
    - Applies environment-specific patches for Ingress and ConfigMaps.

## 🔄 GitOps Workflow with ArgoCD

ArgoCD acts as the cluster-side agent that watches the `infrastructure/k8s/` directory.

1.  **Detection:** ArgoCD detects a commit to the `main` branch.
2.  **Comparison:** It compares the YAML in Git with the live objects in the cluster.
3.  **Synchronization:** If a delta is found (e.g., a new image tag bumped by the CI pipeline), ArgoCD automatically applies the changes (automated sync).
4.  **Health Monitoring:** It provides a visual dashboard of the deployment health and resource dependencies.

## 📊 Observability Stack (LGMA)

A significant portion of the platform is dedicated to comprehensive observability, ensuring full visibility into both infrastructure and application performance.

The stack follows the **LGMA** pattern (Loki, Grafana, Prometheus, Alloy/Telegraf):

- **Prometheus:** Scrapes metrics from services and Kubernetes nodes using `node-exporter` and `cAdvisor`.
- **Loki:** Aggregates logs from all containers in the cluster.
- **Grafana:** The single pane of glass for visualization, with pre-provisioned dashboards for fire monitoring analytics and system health.
- **Alloy / Telegraf:** Acts as the high-performance telemetry collectors, bridging the gap between IoT data (MQTT/InfluxDB) and the observability suite.

## 🛡️ Security & Secrets

- **Network Policies:** Restrict traffic between namespaces and ensure only the Ingress controller can talk to the frontend services.
- **Namespace Isolation:** Logical separation between `fire-monitoring-dev` and `fire-monitoring-prod`.
- **Secret Management:** Secrets are injected via environment-specific `secrets.yaml` (handled via Terraform or manual secure injection) and managed as Kubernetes Secret objects.
