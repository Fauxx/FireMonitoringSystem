# Terraform & Multi-Layer IaC Setup (GKE)

This directory houses the Terraform modules and configuration roots used to provision cloud infrastructure and platform components on Google Cloud Platform (GCP).

---

## 🧱 Layer Orchestration

Infrastructure is deployed sequentially to handle resource dependency chains (such as a VPC needing to exist before provisioning the cluster, or the cluster needing to exist before installing Helm charts).

```
gke-dev/
├── 00-bootstrap/     # Sets up WIF auth, CI Service Accounts, and GitHub Actions environments
├── 01-infra/         # Provisions VPC, Subnets, and GKE Cluster
├── 02-platform/      # Deploys Helm charts (ingress-nginx, cert-manager, External Secrets Operator)
└── 03-argocd/        # Deploys the root ArgoCD App-of-Apps manifest & GitHub App credentials
```

### 📂 Directory Index

*   [**`modules/`**](./modules/): Houses reusable module logic:
    *   `gke/cluster/`: Provisions the Google Kubernetes Engine (GKE) cluster with Workload Identity and Dataplane V2.
    *   `gke/dns/`: Configures DNS A records via Cloud DNS (optional if using Cloudflare Tunnels).
    *   `shared/ingress-controller/`: Deploys ingress-nginx.
    *   `shared/github-secrets/`: Syncs GCP WIF configuration to GitHub Actions Environments.
*   [**`environments/`**](./environments/): Configurations for specific deployment targets:
    *   `gke-dev/`: Core development cluster setup.
    *   *(Note: `gke-prod` is planned for a future migration phase)*

---

## 💾 State Management Strategy

This project uses an **environment and layer split** stored securely in a Google Cloud Storage (GCS) Bucket:
*   Bucket Name: `firemonitoring-tfstate` (must be pre-created)
*   State Key: `gke-dev/{layer}/default.tfstate`
*   Shared configurations are defined at `infrastructure/terraform/backend-gcp-common.conf`.

### Prerequisites (Run Once)
Before running Terraform, ensure the GCP project and GCS state bucket exist:

```bash
gcloud projects create firemonitoring-dev --name="FireMonitoring Dev"
gcloud config set project firemonitoring-dev
gcloud billing projects link firemonitoring-dev --billing-account=YOUR_BILLING_ACCOUNT_ID

# Enable APIs
gcloud services enable container.googleapis.com compute.googleapis.com \
    artifactregistry.googleapis.com secretmanager.googleapis.com \
    dns.googleapis.com iam.googleapis.com iamcredentials.googleapis.com \
    cloudresourcemanager.googleapis.com storage.googleapis.com

# Create State Bucket
gcloud storage buckets create gs://firemonitoring-tfstate --location=asia-east1
gcloud storage buckets update gs://firemonitoring-tfstate --versioning
```

### Local Initialization Example:
To run Terraform commands locally, combine the common backend parameters with the environment key files:
```bash
cd infrastructure/terraform/environments/gke-dev/01-infra
terraform init -reconfigure -backend-config=backend.conf
```
Confirm the dry-run plan before deploying:
```bash
terraform plan -var-file=terraform.tfvars
```
Applying resources locally requires GCP application-default credentials (`gcloud auth application-default login`). In CI/CD, Workload Identity Federation (WIF) is used via `.github/workflows/gcp-terraform-deploy.yml`.
