# Dev 03-argocd Terraform Layer

This layer manages the ArgoCD Application (app-of-apps) and repository credentials for GitOps deployments.

## Overview

- **Purpose:** Creates ArgoCD `Application` resource (app-of-apps) that watches your GitOps repository
- **Auto-sync:** Configured to automatically sync when manifests change in the GitOps repo
- **SSH access:** Stores ArgoCD SSH repo credential (SSH key for read-only GitOps repo access)

## Prerequisites

1. **GitOps repository:** A separate Git repository (e.g., `gitops-repo`) containing Kustomize/Helm manifests in `apps/` folder
2. **SSH deploy key:** Generate a read-only SSH key for ArgoCD to clone the GitOps repo
3. **Terraform state:** Remote state in DigitalOcean Spaces (shared with `01-infra` and `02-platform`)

## Setup Steps

### 1. Generate SSH Deploy Key

```bash
ssh-keygen -t ed25519 -f argocd-deploy -N ''
cat argocd-deploy  # Copy private key (for terraform.tfvars)
cat argocd-deploy.pub  # Add to GitOps repo as deploy key (read-only)
```

### 2. Add Deploy Key to GitOps Repo

On your GitOps repository:
- Go to Settings → Deploy keys
- Click "Add deploy key"
- Paste `argocd-deploy.pub` content
- **Uncheck** "Allow write access" (read-only for security)
- Click "Add key"

### 3. Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
remote_state_bucket     = "tup-firemonitoring-state"
infra_state_key         = "dev/01-infra/terraform.tfstate"
remote_state_region     = "us-east-1"
remote_state_endpoint   = "sgp1.digitaloceanspaces.com"

gitops_repo_url         = "git@github.com:YOUR_ORG/gitops-repo.git"
gitops_repo_branch      = "main"
gitops_repo_apps_path   = "apps"
gitops_repo_ssh_private_key = "base64-encode-of-private-key"  # base64 argocd-deploy
```

### 4. Base64-encode SSH Private Key

```bash
base64 -w0 argocd-deploy > /tmp/key.b64
cat /tmp/key.b64  # Copy and paste into terraform.tfvars
```

### 5. Initialize and Apply

```bash
export AWS_ACCESS_KEY_ID="<YOUR_SPACES_KEY>"
export AWS_SECRET_ACCESS_KEY="<YOUR_SPACES_SECRET>"
export AWS_REGION="us-east-1"
export AWS_EC2_METADATA_DISABLED=true

terraform init -reconfigure \
  -backend-config=../../../backend-common.conf \
  -backend-config=backend.conf

terraform validate
terraform plan
terraform apply
```

## What Gets Created

- `Application` resource named `apps` in `argocd` namespace
  - Points to your GitOps repo URL
  - Auto-syncs on Git changes
  - Watches `apps/` folder for manifests

- `Secret` named `argocd-repo-ssh` in `argocd` namespace
  - Contains the SSH private key for cloning the GitOps repo
  - Used by ArgoCD to authenticate to Git

## Verify Deployment

```bash
# Check the Application
argocd app get apps

# Watch sync status
argocd app wait apps --sync

# View ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Visit https://localhost:8080 (use ArgoCD password)
```

## GitOps Repo Structure

Expected structure in your GitOps repo:

```
gitops-repo/
├── apps/
│   ├── api/
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       └── prod/
│   ├── dashboard/
│   └── etl-processor/
├── infra/
│   └── sealed-secrets/
└── README.md
```

## Troubleshooting

### ArgoCD can't access the Git repo

- Verify SSH key is added to GitOps repo deploy keys
- Check secret is created: `kubectl -n argocd get secret argocd-repo-ssh`
- Test SSH manually: `ssh -i argocd-deploy git@github.com`

### Application not syncing

- Check ArgoCD Application status: `argocd app get apps`
- View logs: `kubectl -n argocd logs -f deployment/argocd-application-controller`
- Verify manifests are in correct path in GitOps repo

### Manifest parsing errors

- Ensure Kustomize overlays have `kustomization.yaml` in `base/` and `overlays/`
- Test locally: `kustomize build infrastructure/k8s/overlays/dev`

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [SSH Repository Setup](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/)
