# Prod 03-argocd Terraform Layer

This layer manages the ArgoCD `Application` (app-of-apps) and repository credentials for GitOps deployments in the *prod* cluster.

## Purpose

- Create an `Application` resource in the `argocd` namespace that points to `infrastructure/k8s/overlays/prod` by default.
- Store a Kubernetes secret `argocd-repo-ssh` containing the SSH private key for ArgoCD to clone the monorepo (if provided).

## Differences vs Dev

- `gitops_repo_apps_path` defaults to `infrastructure/k8s/overlays/prod`.
- Terraform state key is `prod/03-argocd/terraform.tfstate`.
- Use the `production` workflow for apply with required reviewers.
- The layer reads cluster credentials using `do_token` and the infra `cluster_id` output.

## Setup Steps

1. Generate or reuse an SSH deploy key for ArgoCD and add the public key as a **Deploy key** (read-only) on the repo.

```bash
ssh-keygen -t ed25519 -f argocd-deploy-prod -N ''
base64 -w0 argocd-deploy-prod > /tmp/argocd-deploy-prod.b64
```

2. Create `terraform.tfvars` (or set environment variables) using `terraform.tfvars.example`.

  Make sure `do_token` is set so Terraform can fetch the current kubeconfig from DigitalOcean.

3. Initialize & plan (example):

```bash
export AWS_ACCESS_KEY_ID="<SPACES_KEY>"
export AWS_SECRET_ACCESS_KEY="<SPACES_SECRET>"
export AWS_REGION="us-east-1"
export AWS_EC2_METADATA_DISABLED=true
export TF_VAR_do_token="<YOUR_DIGITALOCEAN_TOKEN>"

cd infrastructure/terraform/environments/prod/03-argocd
terraform init -reconfigure \
  -backend-config=../../../backend-common.conf \
  -backend-config=backend.conf
terraform validate
terraform plan
```

4. Apply only after approvals via the `.github/workflows/terraform-deploy-prod.yml` workflow (it targets the `production` environment).

## Troubleshooting

- If ArgoCD cannot clone the repo, verify the `argocd-repo-ssh` secret exists and the public key is added to the repo deploy keys.
- Check ArgoCD UI and `argocd app get apps` for sync errors.

