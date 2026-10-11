# 🌍 Terraform Environments (`infrastructure/terraform/environments/`)

Multi-layer Terraform root configurations for Google Cloud Platform (GCP) and Google Kubernetes Engine (GKE).

---

## 🏗️ Layered Architecture

To isolate blast radius and enforce dependency order, each environment is partitioned into 4 strictly ordered layers:

```text
environments/
├── gke-dev/                  # Development GKE Environment
│   ├── 00-bootstrap/         # WIF auth, CI/CD IAM, GitHub App secrets
│   ├── 01-infra/             # VPC network, subnets, GKE cluster, Cloud SQL
│   ├── 02-platform/          # Cluster addons (Ingress NGINX, cert-manager)
│   └── 03-argocd/            # ArgoCD GitOps root application deployment
│
└── gke-prod/                 # Production GKE Environment
    ├── 00-bootstrap/         # Production WIF auth & CI/CD credentials
    ├── 01-infra/             # Production VPC network, GKE cluster, Cloud SQL
    ├── 02-platform/          # Production cluster addons
    └── 03-argocd/            # Production ArgoCD GitOps deployment
```

---

## 🚦 Layer Execution Order

Layers must be applied sequentially from lowest to highest:

| Layer | Name | Scope & Responsibilities |
| :---: | :--- | :--- |
| **00** | **Bootstrap** | Workload Identity Federation (WIF) pools, CI Service Accounts, and GitHub Actions OIDC integration. |
| **01** | **Infra** | Core VPC networks, subnet routing, GKE regional cluster, Cloud SQL PostgreSQL instance. |
| **02** | **Platform** | Ingress controllers, cert-manager, cluster-wide CRDs and operators. |
| **03** | **ArgoCD** | ArgoCD server installation and GitOps App-of-Apps root declaration pointing to `infrastructure/k8s/overlays/`. |

---

## ⚙️ Execution Commands

### In CI/CD
Automated via `.github/workflows/gcp-terraform-deploy.yml` on pull request merge or release tags using Workload Identity Federation.

### Local Execution via Makefile
```bash
# Development
make gke-dev-bootstrap-plan
make gke-dev-infra-plan
make gke-dev-platform-plan
make gke-dev-argocd-plan

# Production
make gke-prod-bootstrap-plan
make gke-prod-infra-plan
```
