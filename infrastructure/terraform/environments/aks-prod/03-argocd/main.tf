# ==============================================================================
# 1. STATE & BACKEND PLUMBING (Configured via CLI/Backend Files)
# ==============================================================================
terraform {
  backend "azurerm" {}
}

# ------------------------------------------------------------------------------
# Remote State Discovery (Azure Blob State)
# ------------------------------------------------------------------------------
data "terraform_remote_state" "infra" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group
    storage_account_name = var.tfstate_storage_account
    container_name       = var.tfstate_container
    key                  = var.infra_state_key
  }
}

# ==============================================================================
# 2. DYNAMIC PROVIDER INITIALIZATION (Pure Dynamic State Inversion)
# ==============================================================================
provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "convert-kubeconfig",
      "-l", "spn",
      "--client-id", var.azure_client_id,
      "--client-secret", var.azure_client_secret,
      "--tenant-id", var.azure_tenant_id
    ]
  }
}

# ==============================================================================
# 3. ARGOCD REPOSITORY CREDENTIALS CONFIGURATION (The GitHub App Handshake)
# ==============================================================================
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
# The existing K8s manifests and Kustomize overlays are cloud-agnostic.
# ArgoCD on AKS will reconcile the SAME overlays used by the DigitalOcean cluster.
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
