terraform {
  backend "s3" {}
}
# -------------------------
# Remote State (Layer 1)
# -------------------------
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
    skip_s3_checksum            = true
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
