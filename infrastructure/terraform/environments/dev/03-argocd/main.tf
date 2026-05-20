# ==============================================================================
# 1. STATE & BACKEND PLUMBING (Configured via CLI/Backend Files)
# ==============================================================================
terraform {
  backend "s3" {}
  # Inherits global required_providers universally via your versions.tf symlink!
}

# ------------------------------------------------------------------------------
# Remote State Discovery (SGP1 Space State Bucket)
# ------------------------------------------------------------------------------
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket                      = var.remote_state_bucket
    key                         = var.infra_state_key
    region                      = var.remote_state_region
    endpoints                   = { s3 = "https://${var.remote_state_endpoint}" }
    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}

# FIX: Fetch fresh, dynamic credentials to bypass short-lived token expiration
data "digitalocean_kubernetes_cluster" "live" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}

# ==============================================================================
# 2. DYNAMIC PROVIDER INITIALIZATION (Pure Dynamic State Inversion)
# ==============================================================================

provider "digitalocean" {
  token = var.do_token
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
  # ALIGNED: Uses the live, auto-refreshing token instead of stale static state output
  token                  = data.digitalocean_kubernetes_cluster.live.kube_config[0].token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)
}

# ==============================================================================
# 3. ARGOCD REPOSITORY CREDENTIALS CONFIGURATION (The GitHub App Handshake)
# ==============================================================================
# ALIGNED: Swapped to kubernetes_secret_v1 to clear the deprecation warning
resource "kubernetes_secret_v1" "argocd_github_app_creds" {
  metadata {
    name      = "repo-github-app-creds"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    type                      = "git"
    url                       = var.gitops_repo_url
    githubAppID               = var.github_app_id
    githubAppIDInstallationID = var.github_app_installation_id
    githubAppPrivateKey       = replace(var.github_app_private_key, "\\n", "\n")
  }
}

# ==============================================================================
# 4. THE ROOT APPLICATION (App-of-Apps Pattern Deployment)
# ==============================================================================
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

  depends_on = [kubernetes_secret_v1.argocd_github_app_creds]
}