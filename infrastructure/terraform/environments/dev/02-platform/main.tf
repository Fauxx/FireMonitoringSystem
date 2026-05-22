# ==============================================================================
# 1. STATE & BACKEND PLUMBING (Configured via CLI/Backend Files)
# ==============================================================================
terraform {
  backend "s3" {}
}

# ------------------------------------------------------------------------------
# Remote State Discovery (SGP1 Space State Bucket - Reading from 01-infra!)
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
      replicas = 2 # Increases UI concurrency and stops UI connection hangs
      service  = { type = "LoadBalancer" }
      resources = {
        limits   = { cpu = "500m", memory = "512Mi" }
        requests = { cpu = "100m", memory = "256Mi" }
      }
    }
    repoServer = {
      # Grants dedicated horsepower for generating application manifest diffs quickly
      resources = {
        limits   = { cpu = "1000m", memory = "1Gi" }
        requests = { cpu = "250m", memory = "256Mi" }
      }
    }
    controller = {
      replicas = 2 # Fast cluster sync execution state
      resources = {
        limits   = { cpu = "1000m", memory = "1Gi" }
        requests = { cpu = "500m", memory = "512Mi" }
      }
    }
    redis = {
      enabled = true
      # Protects Redis cache state from hitting Out-Of-Memory (OOM) tracking walls
      resources = {
        limits   = { cpu = "500m", memory = "512Mi" }
        requests = { cpu = "100m", memory = "128Mi" }
      }
    }
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
# 4. SHARED APPLICATION SECRETS (Injected from CI runtime)
# ------------------------------------------------------------------------------
resource "kubernetes_secret_v1" "fire_monitoring_secrets" {
  metadata {
    name      = "fire-monitoring-secrets"
    namespace = kubernetes_namespace_v1.fire_monitoring_dev.metadata[0].name
  }

  data = {
    # We pass the PEM key here; K8s will handle the multi-line string correctly in the base64 payload.
    # This allows the API/ETL to mount it as a file later.
    "github-app-private-key.pem" = var.github_app_private_key
    "github-app-id"              = var.github_app_id
    "github-app-installation-id" = var.github_app_installation_id

    # Also include the database URL for shared connectivity
    "DATABASE_URL" = "postgresql://fireuser:changeme@db:5432/fire_monitoring"
  }

  type = "Opaque"
}