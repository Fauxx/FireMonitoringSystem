# 📦 Terraform Modules (`infrastructure/terraform/modules/`)

Reusable, opinionated Terraform modules supporting the multi-environment GKE infrastructure.

---

## 📂 Modules Directory Index

```text
modules/
├── gke/
│   ├── cluster/              # Regional GKE Cluster, node pools, Dataplane V2, Workload Identity
│   └── dns/                  # Google Cloud DNS zones and record sets
│
├── gcp/
│   └── cloudsql/             # Cloud SQL PostgreSQL instance, users, and IAM database authentication
│
└── shared/
    ├── argocd/               # ArgoCD Helm deployment and initial admin credentials
    ├── ingress-controller/   # Ingress-NGINX Helm chart installation
    └── github-secrets/       # Syncs GCP outputs (WIF provider, SA emails) to GitHub Actions
```

---

## 🛠️ Usage Example

```hcl
module "gke_cluster" {
  source = "../../modules/gke/cluster"

  project_id   = var.project_id
  region       = var.region
  cluster_name = "gke-firemonitoring-dev-01"
  network      = module.vpc.network_name
  subnetwork   = module.vpc.subnet_name
}
```

---

## 🔒 Design Conventions
* **Workload Identity**: Enabled by default on all GKE node pools.
* **Least Privilege**: Modules do not attach default compute service accounts. Dedicated IAM Service Accounts are created per module.
* **Variable Validation**: Inputs enforce strict CIDR blocks, naming conventions, and resource tags.
