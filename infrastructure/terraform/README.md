# 🏗️ Terraform & Multi-Layer Infrastructure as Code (`infrastructure/terraform/`)

[![Terraform](https://img.shields.io/badge/IaC-Terraform%201.7+-844FBA?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Cloud](https://img.shields.io/badge/Cloud-Google%20Cloud%20Platform-4285F4?style=flat&logo=google-cloud&logoColor=white)](https://cloud.google.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-GKE%20Dataplane%20V2-326CE5?style=flat&logo=kubernetes&logoColor=white)](https://cloud.google.com/kubernetes-engine)
[![Security](https://img.shields.io/badge/IAM-Workload%20Identity%20Federation-008080?style=flat)](#)

This directory contains the modular, multi-layer Infrastructure as Code (IaC) configurations used to provision cloud infrastructure and platform components on **Google Cloud Platform (GCP)** and **Google Kubernetes Engine (GKE)**.

---

## 🧱 4-Layer Sequential Orchestration

To eliminate state locking bottlenecks and enforce strict resource dependency ordering, the infrastructure is decomposed into 4 sequentially ordered layers:

```
environments/
├── gke-dev/                  # Staging / Development Environment
│   ├── 00-bootstrap/         # WIF auth, CI Service Accounts, GitHub Actions environment secrets
│   ├── 01-infra/             # VPC network, subnets, GKE cluster, Cloud SQL PostgreSQL
│   ├── 02-platform/          # Cluster Helm charts (ingress-nginx, cert-manager)
│   └── 03-argocd/            # ArgoCD GitOps root application declaration & GitHub App credentials
│
└── gke-prod/                 # Production Environment
    ├── 00-bootstrap/         # Production WIF auth & CI/CD credentials
    ├── 01-infra/             # Production VPC network, GKE cluster, Cloud SQL
    ├── 02-platform/          # Production cluster addons
    └── 03-argocd/            # Production ArgoCD GitOps deployment
```

### Layer Responsibilities
| Layer | Scope | Key Resources Provisioned |
|---|---|---|
| **`00-bootstrap`** | IAM & CI/CD Foundations | GCP Workload Identity Federation (WIF) pools, CI Service Accounts, IAM role bindings, and GitHub Actions Environment secret synchronization. |
| **`01-infra`** | Core Cloud Infrastructure | Custom VPC, subnets, GKE cluster with Dataplane V2 (eBPF) & Workload Identity, Cloud SQL PostgreSQL instance, and Cloud DNS zones. |
| **`02-platform`** | Cluster-Level Controllers | Ingress-Nginx controller (`externalTrafficPolicy: Local`), Cert-Manager for automated TLS, and cluster-wide RBAC. |
| **`03-argocd`** | GitOps Bootstrapping | ArgoCD Helm installation, GitHub App credentials synchronization, and registration of the root `App-of-Apps` manifest pointing to `infrastructure/k8s/overlays/`. |

---

## 📂 Directory Index

*   [**`environments/`**](./environments/): Root module configurations for specific deployment targets:
    *   [`gke-dev/`](./environments/gke-dev/): Staging / Development cluster.
    *   [`gke-prod/`](./environments/gke-prod/): Production cluster with scaled capacity and production cert issuers.
    *   👉 See [**Environments Guide 📖**](./environments/README.md)
*   [**`modules/`**](./modules/): Reusable, opinionated Terraform modules:
    *   [`gke/cluster/`](./modules/gke/cluster/): Regional GKE cluster with Dataplane V2, shielded nodes, and Workload Identity.
    *   [`gke/dns/`](./modules/gke/dns/): Cloud DNS managed zones and record sets.
    *   [`gcp/cloudsql/`](./modules/gcp/cloudsql/): Managed PostgreSQL instance with IAM authentication and automated backups.
    *   [`shared/ingress-controller/`](./modules/shared/ingress-controller/): Ingress-Nginx Helm deployment.
    *   [`shared/argocd/`](./modules/shared/argocd/): ArgoCD GitOps deployment and root application bootstrapping.
    *   [`shared/github-secrets/`](./modules/shared/github-secrets/): Automated sync of GCP outputs into GitHub Actions environments.
    *   👉 See [**Modules Guide 📖**](./modules/README.md)

---

## 💾 State Management Strategy

Terraform remote state is stored securely in Google Cloud Storage (GCS) with layer and environment isolation:
*   **GCS Bucket**: `gs://firemonitoring-tfstate` (with object versioning enabled)
*   **Dev State Keys**: `gke-dev/{layer}/default.tfstate`
*   **Prod State Keys**: `gke-prod/{layer}/default.tfstate`
*   Shared backend configuration is defined in [`backend-gcp-common.conf`](./backend-gcp-common.conf).

---

## 🔐 Zero-Trust Security & IAM Posture

1. **Passwordless CI/CD**: Pull requests and main branch deployments authenticate to GCP via **Workload Identity Federation (WIF)**, eliminating static JSON service account credentials.
2. **GKE Workload Identity**: Eliminates static database credentials inside pods; Kubernetes Service Accounts (KSAs) bind directly to Google Service Accounts (GSAs) to access Cloud SQL.
3. **Dataplane V2**: Built-in eBPF network virtualization replaces legacy iptables and enforces Kubernetes NetworkPolicies with sub-millisecond overhead.

---

## 🚦 Execution

### Automated CI/CD
Applied automatically via [`.github/workflows/gcp-terraform-deploy.yml`](../../.github/workflows/gcp-terraform-deploy.yml) when Terraform files change on `main`, or triggered manually via `workflow_dispatch`.

### Local Execution via Makefile
```bash
# Staging (gke-dev)
make gke-dev-bootstrap-plan
make gke-dev-infra-plan
make gke-dev-platform-plan
make gke-dev-argocd-plan

# Production (gke-prod)
make gke-prod-bootstrap-plan
make gke-prod-infra-plan
```
