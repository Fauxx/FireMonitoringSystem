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

data "digitalocean_kubernetes_cluster" "live" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}

# -------------------------
# Providers
# -------------------------
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

# -------------------------
# Namespaces
# -------------------------
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace" "fire_monitoring_prod" {
  metadata {
    name = "fire-monitoring-prod"
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
# Ingress Controller
# -------------------------
module "ingress_controller" {
  source            = "../../../modules/ingress-controller"
  loadbalancer_name = "doks-prod-ingress-loadbalancer"
}

# -------------------------
# Cert Manager
# -------------------------
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  version    = "v1.13.0"

  values = [yamlencode({
    installCRDs = true
  })]
}

# -------------------------
# Production DNS Records
# -------------------------
resource "digitalocean_record" "root" {
  domain = data.terraform_remote_state.infra.outputs.domain_name
  type   = "A"
  name   = "@"
  value  = module.ingress_controller.load_balancer_ip
  ttl    = 300
}

resource "digitalocean_record" "ops" {
  domain = data.terraform_remote_state.infra.outputs.domain_name
  type   = "A"
  name   = "ops"
  value  = module.ingress_controller.load_balancer_ip
  ttl    = 300
}

# -------------------------
# Shared Application Secrets
# -------------------------
resource "kubernetes_secret_v1" "fire_monitoring_secrets" {
  metadata {
    name      = "fire-monitoring-secrets"
    namespace = kubernetes_namespace.fire_monitoring_prod.metadata[0].name
  }

  data = {
    "github-app-private-key.pem" = var.github_app_private_key
    "github-app-id"              = var.github_app_id
    "github-app-installation-id" = var.github_app_installation_id

    "POSTGRES_PASSWORD"          = "prodsecuredbpass123"
    "DATABASE_URL"               = "postgresql://postgres:prodsecuredbpass123@db:5432/fire_monitoring"
  }

  type = "Opaque"
}


