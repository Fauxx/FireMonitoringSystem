terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    endpoints = {
      s3 = "https://sgp1.digitaloceanspaces.com"
    }

    bucket = "tup-firemonitoring-state"
    key    = "dev/03-argocd/terraform.tfstate"
    region = "us-east-1"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true

    use_path_style = true
  }

  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    local      = { source = "hashicorp/local",      version = "~> 2.2" }
  }
}

# ------------------------------------------------------------------------------
# Remote State Discovery (Reading Cluster Access from Layer 1)
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

# ------------------------------------------------------------------------------
# Provider Initialization (Pure Dynamic State Inversion)
# ------------------------------------------------------------------------------
resource "local_file" "kubeconfig" {
  # Write the raw kubeconfig from Layer 01 infra state into a local file for provider use
  content  = data.terraform_remote_state.infra.outputs.kubeconfig_raw
  filename = "${path.module}/.kubeconfig"
  file_permission = "0600"
}

provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
  # Keep explicit host/token as a fallback if kubeconfig is not present/valid
  host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
  token                  = data.terraform_remote_state.infra.outputs.cluster_token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)
}

# ------------------------------------------------------------------------------
# ArgoCD Repository Credentials Configuration (The GitHub App Handshake)
# ------------------------------------------------------------------------------
resource "kubernetes_secret" "argocd_github_app_creds" {
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

# ------------------------------------------------------------------------------
# The Root Application (App-of-Apps Pattern Deployment)
# ------------------------------------------------------------------------------
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

  depends_on = [kubernetes_secret.argocd_github_app_creds]
}