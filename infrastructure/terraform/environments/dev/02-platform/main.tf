terraform {
  backend "s3" {
    bucket                      = "fire-monitoring-tfstate"
    region                      = "us-east-1"
    endpoint                    = "https://sgp1.digitaloceanspaces.com"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    
    # ADD THESE HERE instead of passing them in the CLI
    skip_requesting_account_id  = true
    use_path_style              = true
  }
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

# ------------------------------------------------------------------------------
# Provider Initializations
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Platform Core Engine (Local Helm Deployments)
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "fire_monitoring_dev" {
  metadata {
    name = "fire-monitoring-dev"
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [yamlencode({
    server = {
      service = { type = "LoadBalancer" }
    }
    controller = { replicas = 2 }
    redis      = { enabled = true }
  })]
}

data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
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
  value  = data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].ip
  ttl    = 300
}

# ------------------------------------------------------------------------------
# Pull-Based GitOps Handshake Module Caller (Fully Aligned & Dynamic)
# ------------------------------------------------------------------------------
module "github_secrets" {
  source = "../../../modules/github-secrets"

  # Dynamic environment assignment
  github_environment         = var.github_environment

  # FIX: Change 'github_repo' to 'github_repository' to match the module input name!
  github_repository           = var.github_repository
  github_app_id               = var.github_app_id
  github_app_installation_id  = var.github_app_installation_id
  github_app_private_key      = var.github_app_private_key
  github_app_state_access_key = var.github_app_state_access_key
  github_app_state_secret_key = var.github_app_state_secret_key

}
