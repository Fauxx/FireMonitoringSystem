terraform {
  backend "azurerm" {
    resource_group_name  = "rg-firemonitoring-tfstate-01"
    storage_account_name = "stfiremonitortfstate"
    container_name       = "tfstate"
    key                  = "aks-dev/02-platform/terraform.tfstate"
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "infra" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-firemonitoring-tfstate-01"
    storage_account_name = "stfiremonitortfstate"
    container_name       = "tfstate"
    key                  = "aks-dev/01-infra/terraform.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  use_oidc        = true
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--login",
      "azurecli",
      "--server-id",
      "6dae42f8-4368-4678-94ff-3960e28e3630"
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
        "get-token",
        "--login",
        "azurecli",
        "--server-id",
        "6dae42f8-4368-4678-94ff-3960e28e3630"
      ]
    }
  }
}

module "ingress_controller" {
  source = "../../../modules/shared/ingress-controller"
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.17.0"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }

  depends_on = [module.ingress_controller]
}

resource "helm_release" "csi_secrets_store_provider_azure" {
  name       = "csi-secrets-store-provider-azure"
  repository = "https://azure.github.io/secrets-store-csi-driver-provider-azure/charts"
  chart      = "csi-secrets-store-provider-azure"
  namespace  = "kube-system"
  version    = "1.6.2"

  set {
    name  = "secrets-store-csi-driver.syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "secrets-store-csi-driver.enableSecretRotation"
    value = "true"
  }
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = data.terraform_remote_state.infra.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.terraform_remote_state.infra.outputs.kubelet_identity_object_id
}

module "ingress_dns" {
  source = "../../../modules/aks/dns"
  count  = var.dns_zone_name != "" ? 1 : 0

  a_records = {
    "@"       = module.ingress_controller.load_balancer_ip
    "argocd"  = module.ingress_controller.load_balancer_ip
    "dev"     = module.ingress_controller.load_balancer_ip
    "ops.dev" = module.ingress_controller.load_balancer_ip
  }
  dns_zone_name       = var.dns_zone_name
  resource_group_name = data.terraform_remote_state.infra.outputs.resource_group_name
}

module "argocd" {
  source = "../../../modules/shared/argocd"

  gitops_repo_url            = var.gitops_repo_url
  gitops_revision            = var.gitops_revision
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key
  argocd_version             = var.argocd_version
}
