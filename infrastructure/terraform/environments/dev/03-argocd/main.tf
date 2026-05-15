terraform {
  required_version = ">= 1.5.0"

  backend "s3" {} # Uses your backend-common.conf

  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
  }
}

# -------------------------
# Remote State (Pulling from DO Space)
# -------------------------
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket              = var.remote_state_bucket
    key                 = var.infra_state_key
    region              = var.remote_state_region
    endpoints           = { s3 = "https://${var.remote_state_endpoint}" }
    use_path_style      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}

# -------------------------
# Providers
# -------------------------
provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
  token                  = data.terraform_remote_state.infra.outputs.cluster_token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)
}

# -------------------------
# ArgoCD App-of-Apps
# -------------------------
resource "kubernetes_manifest" "argocd_apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "apps"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_repo_branch
        path           = var.gitops_repo_apps_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = []
}

# -------------------------
# ArgoCD Repo Credential (SSH for GitOps repo access)
# -------------------------
resource "kubernetes_secret" "argocd_repo_ssh" {
  count = length(trimspace(var.gitops_repo_ssh_private_key)) > 0 ? 1 : 0

  metadata {
    name      = "argocd-repo-ssh"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    type          = "git"
    url           = var.gitops_repo_url
    sshPrivateKey = var.gitops_repo_ssh_private_key
  }
}
