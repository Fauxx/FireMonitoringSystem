terraform {
  required_version = ">= 1.5.0"

  backend "s3" {} # Uses your backend-common.conf

  required_providers {
    kubernetes   = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    helm         = { source = "hashicorp/helm", version = "~> 2.13" }
    digitalocean = { source = "digitalocean/digitalocean", version = "~> 2.34" }
    github       = { source = "integrations/github", version = "~> 6.0" }
  }
}

# -------------------------
# Remote State (Pulling from DO Space)
# -------------------------
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    # Remote state location (DigitalOcean Spaces, S3 compatible)
    bucket = var.remote_state_bucket
    key    = var.infra_state_key
    # Spaces is S3-compatible (not AWS STS), so disable AWS account validations.
    region                  = var.remote_state_region
    endpoints               = { s3 = "https://${var.remote_state_endpoint}" }
    use_path_style          = true
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

provider "digitalocean" {
  token = var.do_token
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

# -------------------------
# Platform Logic (ArgoCD)
# -------------------------
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

# -------------------------
# DNS (Pulled from Infra)
# -------------------------
resource "digitalocean_record" "argocd" {
  domain = data.terraform_remote_state.infra.outputs.domain_name # <--- Pulled from Space
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
  enabled            = true
  github_repo        = var.github_repository
  github_environment = "dev" # <--- This is how it knows! (Use "prod" in your prod folder)

  # 2. Connection Data
  do_token   = var.do_token
  cluster_id = data.terraform_remote_state.infra.outputs.cluster_id

  # 3. Kubeconfig: Mapping the 'raw' output to the module's 'kubeconfig' input
  kubeconfig = data.terraform_remote_state.infra.outputs.kubeconfig_raw

  # 4. ArgoCD/DevOps Details
  argocd_server     = "https://${digitalocean_record.argocd.fqdn}"
  argocd_auth_token = var.argocd_auth_token
}