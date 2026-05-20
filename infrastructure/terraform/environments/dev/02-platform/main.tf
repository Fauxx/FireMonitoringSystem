# ==============================================================================
# 1. STATE & BACKEND PLUMBING (Configured via CLI/Backend Files)
# ==============================================================================
terraform {
  backend "s3" {}
  # required_providers block is completely removed from here because 
  # it's inherited universally from your symlinked versions.tf!
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

data "digitalocean_kubernetes_cluster" "live" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}

# ==============================================================================
# 2. DYNAMIC PROVIDER CONFIGURATIONS (Evaluated at Runtime)
# ==============================================================================
provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
  token                  = data.digitalocean_kubernetes_cluster.live.kube_config[0].token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
    token                  = data.digitalocean_kubernetes_cluster.live.kube_config[0].token
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)
  }
}

provider "digitalocean" {
  token = var.do_token
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

# ==============================================================================
# 3. PLATFORM ENGINE LOGIC (Namespaces & Resources)
# ==============================================================================
resource "kubernetes_namespace_v1" "fire_monitoring_dev" {
  metadata {
    name = "fire-monitoring-dev"
  }
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  values = [yamlencode({
    server = {
      service = { type = "LoadBalancer" }
    }
    controller = { replicas = 2 }
    redis      = { enabled = true }
  })]
}

data "kubernetes_service_v1" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
  }
  depends_on = [helm_release.argocd]
}

# ------------------------------------------------------------------------------
# Networking & Route Mapping
# ------------------------------------------------------------------------------
resource "digitalocean_record" "argocd" {
  domain = data.terraform_remote_state.infra.outputs.domain_name
  type   = "A"
  name   = "argocd"
  value  = data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].ip
  ttl    = 300
}
# ------------------------------------------------------------------------------
# Pull-Based GitOps Handshake Module Caller
# ------------------------------------------------------------------------------
module "github_secrets" {
  source = "../../../modules/github-secrets"

  github_environment          = var.github_environment
  github_repository           = var.github_repository
  github_app_id               = var.github_app_id
  github_app_installation_id  = var.github_app_installation_id
  github_app_private_key      = var.github_app_private_key
  github_app_state_access_key = var.github_app_state_access_key
  github_app_state_secret_key = var.github_app_state_secret_key
}