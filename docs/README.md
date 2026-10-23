# 📚 Documentation Index

This repository uses a structured documentation layout covering Architecture, Infrastructure as Code (IaC), GitOps, Zero-Trust Networking, and Operational Runbooks for the **Fire Monitoring System**.

---

## 🏛️ System Architecture

*   **[00 — Architecture Overview](./architecture/00-overview.md)**: Decoupled microservice topology, data ingestion flows, and source-of-truth model.
*   **[01 — GCP & GKE Infrastructure](./architecture/01-gcp-gke.md)**: Google Cloud Platform foundation, private GKE cluster, Dataplane V2 (eBPF), and Workload Identity.
*   **[02 — Kubernetes & GitOps Manifests](./architecture/02-kubernetes.md)**: Kustomize Base/Overlay hierarchy, ArgoCD sync wave orchestration, and Cloudflare Tunnels.
*   **[03 — Application Layer & Telemetry](./architecture/03-application.md)**: Node.js Express REST API, React 19 Command Center, Python pandas ETL, and Mosquitto MQTT.
*   **[04 — Observability & Telemetry Stack](./architecture/04-observability.md)**: Prometheus metrics, Loki log shipping with Grafana Alloy, and custom Grafana dashboards.

---

## 📸 Portfolio & Live Demonstrations

*   **[Portfolio Assets & Visual Catalog](./portfolio_assets/README.md)**: High-resolution screenshots, interactive map demos, and live animated GIF / MP4 telemetry captures from `dev.fires.systems`.

---

## 📜 Governance & Architecture Decision Records (ADRs)

*   **[Architecture Decision Records (ADR) Index](./ADR/README.md)**:
    *   [ADR-0001: Adoption of GitOps](./ADR/0001-adoption-of-gitops.md)
    *   [ADR-0002: Zero-Trust Networking](./ADR/0002-zero-trust-networking.md)

---

## 🛠️ Developer & Operational Guides

*   **[Local Kind Kubernetes Guide](./LOCAL_KIND_GUIDE.md)**: Step-by-step instructions for running the complete stack locally in Kind with Podman/Docker.
*   **[Kubernetes Networking Runbook](../infrastructure/k8s/NETWORKING_SETUP.md)**: Ingress routing, Cloudflare tunnels, TLS certificates, and port-forwarding.
*   **[GitOps & GitHub App Setup Guide](../.github/GITOPS_SETUP.md)**: Instructions for configuring GitHub App credentials and ArgoCD automated sync.
