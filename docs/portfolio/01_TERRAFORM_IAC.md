# Terraform & Multi-Layer IaC

This project utilizes a **Layered Infrastructure as Code** strategy to manage complexity, reduce blast radius, and ensure clean separation of concerns between core cloud resources and cluster-level platform services.

## 🧱 Layer Orchestration

Infrastructure is deployed in a strictly sequential order. This ensures that dependencies (like a Kubernetes cluster existing before attempting to install ArgoCD) are met.

| Layer | Name | Responsibility | Key Modules Used |
| :--- | :--- | :--- | :--- |
| **00** | `bootstrap` | Initial cloud project setup and remote state locking. | - |
| **01** | `infra` | Core networking, VPCs, Firewalls, and Managed Kubernetes (DOKS). | `cluster`, `dns` |
| **02** | `platform` | Cluster-wide controllers and basic platform utilities. | `cert-manager`, `ingress-controller` |
| **03** | `argocd` | Bootstrapping the GitOps engine. | `argocd`, `github-secrets` |

## ⚙️ State Management Strategy

To ensure reliability across environments, the project uses:
- **Environment Isolation:** Separate state files for `dev` and `prod`.
- **Backend Commonality:** A shared `backend-common.conf` for S3/Spaces bucket settings, with environment-specific overrides for state keys.
- **Sequential Locking:** Automated pipelines prevent concurrent applies to the same environment layer.

## 🚀 Pipeline Orchestration (GitHub Actions)

### Environment Promotion & Testing
To ensure stability, the project follows a **Sequential Promotion** strategy:
- **Dev as the Testing Ground:** All infrastructure module changes are first applied to the `dev` environment. This allows for validation of the Terraform logic and cluster-level service integration (like Ingress or ArgoCD) before production.
- **Sequential Guardrails:** The GitHub Actions pipeline is configured to ensure that changes must pass validation and application in the `dev` layer before they are considered for `prod` promotion.

## ⚙️ Secret Management Strategy

For security and flexibility, secrets are handled outside of the Git-tracked state:
- **Bootstrap Layer:** Initial cloud credentials (like DigitalOcean tokens) are injected via `terraform.tfvars` (local) or GitHub Actions Secrets (automated).
- **Runtime Secrets:** Application-level secrets (database passwords, API keys) are injected directly into the cluster via the `kubectl` CLI or Terraform-managed Kubernetes resources, ensuring sensitive values never reside in plain-text within the Git repository.

## 🧩 Modular Design

Terraform logic is abstracted into local modules under `infrastructure/terraform/modules/`:
- **`cluster`:** Provisions the DigitalOcean Kubernetes Service (DOKS) with optimized node pools.
- **`argocd`:** Deploys ArgoCD via Helm and configures the initial projects and applications.
- **`github-secrets`:** Dynamically syncs infrastructure outputs (like cluster endpoints or registry credentials) back to GitHub Actions secrets, closing the loop between IaC and CI/CD.
