# ==============================================================================
# 1. STATE & BACKEND PLUMBING (Configured via CLI/Backend Files)
# ==============================================================================
terraform {
  backend "azurerm" {}
}

# ------------------------------------------------------------------------------
# Remote State Discovery (Azure Blob State - Reading from 01-infra!)
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
# 2. DYNAMIC PROVIDER CONFIGURATIONS (Evaluated at Runtime)
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

provider "helm" {
  kubernetes {
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
}

# ==============================================================================
# 3. PLATFORM ENGINE LOGIC (Namespaces & Resources)
# ==============================================================================
resource "kubernetes_namespace_v1" "fire_monitoring_azure_dev" {
  metadata {
    name = "fire-monitoring-aks-prod"
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
      service  = { type = "ClusterIP" }
      insecure = true
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

# NOTE: The ingress-controller module uses DO-specific load balancer annotations.
# On AKS, the Azure Load Balancer is provisioned automatically by the cloud-controller-manager 
# when type=LoadBalancer is set; DO-specific annotations are safely ignored by AKS.
module "ingress_controller" {
  source = "../../../modules/shared/ingress-controller"
}

# ------------------------------------------------------------------------------
# Networking & Route Mapping (Azure DNS)
# ------------------------------------------------------------------------------
module "azure_dns" {
  source = "../../../modules/aks/dns"
  resource_group_name = data.terraform_remote_state.infra.outputs.resource_group_name
  dns_zone_name       = var.dns_zone_name
  
  a_records = [
    {
      name = "@"
      ipv4_address = module.ingress_controller.load_balancer_ip
    },
    {
      name = "argocd"
      ipv4_address = module.ingress_controller.load_balancer_ip
    },
    {
      name = "dev"
      ipv4_address = module.ingress_controller.load_balancer_ip
    },
    {
      name = "ops.dev"
      ipv4_address = module.ingress_controller.load_balancer_ip
    }
  ]
}

# ------------------------------------------------------------------------------
# ArgoCD Network Policies
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "argocd_network_policies" {
  for_each = {
    for idx, doc in split("---", file("${path.module}/../../../../k8s/base/argocd/networkpolicy.yaml")) : idx => doc if trimspace(doc) != ""
  }

  manifest = yamldecode(each.value)

  depends_on = [helm_release.argocd]
}

# ------------------------------------------------------------------------------
# 4. SHARED APPLICATION SECRETS (Injected from CI runtime)
# ------------------------------------------------------------------------------
resource "kubernetes_secret_v1" "fire_monitoring_secrets" {
  metadata {
    name      = "fire-monitoring-secrets"
    namespace = kubernetes_namespace_v1.fire_monitoring_azure_dev.metadata[0].name
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
