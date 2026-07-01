# Terraform & Multi-Layer IaC Setup

This directory houses the Terraform modules and configuration roots used to provision cloud infrastructure and platform components on DigitalOcean.

---

## 🧱 Layer Orchestration

Infrastructure is deployed sequentially to handle resource dependency chains (such as a VPC needing to exist before provisioning the cluster, or the cluster needing to exist before installing Helm charts).

```
dev/
├── 00-bootstrap/     # Sets up remote state buckets (Spaces) & state locks
├── 01-infra/         # Provisions VPC, domain records, and Managed Kubernetes (DOKS)
├── 02-platform/      # Deploys Helm charts (ArgoCD, ingress-nginx) and shared secrets
└── 03-argocd/        # Deploys the root ArgoCD App-of-Apps manifest & GitHub App credentials
```

### 📂 Directory Directory Index

*   [**`modules/`**](./modules/): Houses reusable module logic:
    *   `cluster/`: Provisions the DigitalOcean Kubernetes Service (DOKS) with optimized node pools.
    *   `ingress-controller/`: Deploys ingress-nginx.
    *   `cert-manager/`: Installs cert-manager for automatic HTTPS certificate issuance.
    *   `argocd/`: Boots the ArgoCD Helm chart.
    *   `dns/`: Configures DNS A records in DigitalOcean.
    *   `github-secrets/`: Syncs cloud outputs back to GitHub Repository Secrets for Actions pipelines.
*   [**`environments/`**](./environments/): Configurations for specific deployment targets:
    *   `dev/`: Core development cluster setup.
    *   `prod/`: Core production cluster setup.

---

## 💾 State Management Strategy

This project uses an **environment-only state split** stored securely in DigitalOcean Spaces:
*   State Key: `environments/{env}/terraform.tfstate`
*   Shared configurations are defined at `infrastructure/terraform/backend-common.conf`.

### Local Initialization Example:
To run Terraform commands locally, combine the common backend parameters with the environment key files:
```bash
cd infrastructure/terraform/environments/dev/01-infra
terraform init -reconfigure \
  -backend-config=../../../backend-common.conf \
  -backend-config=backend.conf
```
Confirm the dry-run plan before deploying:
```bash
terraform plan -input=false
```
Applying resources requires proper environment variables (e.g. `TF_VAR_do_token`) injected locally or via CI secrets.
