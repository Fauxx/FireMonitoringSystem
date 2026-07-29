# ==============================================================================
# 1. STATE & BACKEND PLUMBING
# ==============================================================================
terraform {
  backend "azurerm" {}
}

# ------------------------------------------------------------------------------
# 2. PROVIDERS
# ------------------------------------------------------------------------------
provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

# ------------------------------------------------------------------------------
# 3. STORAGE & SECRET PROVISIONING ENGINE
# ------------------------------------------------------------------------------
resource "azurerm_resource_group" "tfstate" {
  name     = var.resource_group_name
  location = var.azure_location
}

resource "azurerm_storage_account" "terraform_state" {
  name                              = var.storage_account_name
  resource_group_name               = azurerm_resource_group.tfstate.name
  location                          = azurerm_resource_group.tfstate.location
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  allow_nested_items_to_be_public   = false
}

resource "azurerm_storage_container" "tfstate" {
  name                  = var.storage_container_name
  storage_account_name  = azurerm_storage_account.terraform_state.name
  container_access_type = "private"
}

module "github_secrets" {
  source = "../../../modules/shared/github-secrets"

  github_environment          = var.github_environment
  github_repository           = var.github_repository
  github_app_id               = var.github_app_id
  github_app_installation_id  = var.github_app_installation_id
  github_app_private_key      = var.github_app_private_key
  github_app_state_access_key = var.github_app_state_access_key
  github_app_state_secret_key = var.github_app_state_secret_key
  do_token                    = var.azure_client_secret # Used as SP secret injection equivalent

  root_domain         = "fires.systems" # Place holder domain to match DO injection pattern
  cluster_name        = var.cluster_name
  node_size           = var.node_vm_size
  node_count          = var.node_count
  remote_state_bucket = var.remote_state_container
  infra_state_key     = var.infra_state_key
  gitops_repo_url     = var.gitops_repo_url
}

# ------------------------------------------------------------------------------
# 4. EXPORTED BASELINE OUTPUTS
# ------------------------------------------------------------------------------
# Provided via outputs.tf
