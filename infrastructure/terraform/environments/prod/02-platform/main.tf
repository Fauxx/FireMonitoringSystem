terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    endpoints = {
      s3 = "https://sgp1.digitaloceanspaces.com"
    }

    bucket = "tup-firemonitoring-state"
    key    = "prod/02-platform/terraform.tfstate"
    region = "us-east-1"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true

    use_path_style = true
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }

    argocd = {
      source  = "argoproj-labs/argocd"
      version = ">= 6.0.0"
    }

    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34"
    }
  }
}
# -------------------------
# Remote State (Layer 1)
# -------------------------
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket    = var.remote_state_bucket
    key       = var.infra_state_key
    region    = var.remote_state_region
    endpoints = { s3 = "https://${var.remote_state_endpoint}" }

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

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
    token                  = data.terraform_remote_state.infra.outputs.cluster_token
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)
  }
}

provider "argocd" {
  server_addr = var.argocd_server
  auth_token  = data.terraform_remote_state.infra.outputs.argocd_manager_token
  insecure    = true
}

provider "digitalocean" {
  token = var.do_token
}

# -------------------------
# Namespace
# -------------------------
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# -------------------------
# ArgoCD install
# -------------------------
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [yamlencode({
    server = {
      service = {
        type = "LoadBalancer"
      }
    }

    controller = {
      replicas = 2
    }

    redis = {
      enabled = true
    }
  })]
}

# -------------------------
# Service lookup
# -------------------------
data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [helm_release.argocd]
}

# -------------------------
# DNS
# -------------------------
resource "digitalocean_record" "argocd" {
  domain = data.terraform_remote_state.infra.outputs.domain_name
  type   = "A"
  name   = "argocd"
  value  = data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].ip
  ttl    = 300
}

# -------------------------
# GitHub Handshake
# -------------------------
module "github_secrets" {
  source = "../../../modules/github-secrets"

  # 1. Identity: Tells the module which repo and environment to target
  enabled            = length(trimspace(var.github_repository)) > 0
  github_repo        = var.github_repository
  github_environment = "production" # <--- Production environment

  # 2. Connection Data
  do_token   = var.do_token
  cluster_id = data.terraform_remote_state.infra.outputs.cluster_id

  # 3. Kubeconfig: Mapping the 'raw' output to the module's 'kubeconfig' input
  kubeconfig = data.terraform_remote_state.infra.outputs.kubeconfig_raw

  # 4. ArgoCD/DevOps Details
  argocd_server     = "https://${digitalocean_record.argocd.fqdn}"
  argocd_auth_token = var.argocd_auth_token

  # 5. GitHub App Credentials (for CI/CD automation)
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key

  # 6. Container Registry Credentials (optional)
  ghcr_deploy_username = var.ghcr_deploy_username
  ghcr_deploy_token    = var.ghcr_deploy_token
}