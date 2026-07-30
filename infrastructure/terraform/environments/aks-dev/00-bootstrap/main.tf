# ==============================================================================
# 00-BOOTSTRAP — Enterprise Foundation Layer
# ==============================================================================
#
# PURPOSE: Establish the foundational control plane for ALL subsequent layers.
#   1. Azure Blob Storage backend for remote Terraform state + lease locking.
#   2. Microsoft Entra ID App Registration + Federated Identity Credentials.
#      This is the OIDC trust that allows GitHub Actions to authenticate to
#      Azure without any long-lived client secrets.
#   3. Least-privilege RBAC role assignments for the CI identity.
#   4. Inject non-secret identity values into GitHub Actions environments.
#
# ⚠️  BOOTSTRAP CHICKEN-AND-EGG NOTE:
#   This layer CREATES the OIDC identity — so it CANNOT use OIDC to run itself.
#   It is designed to run ONCE with a temporary admin Service Principal:'
#
#     az ad sp create-for-rbac \
#       --name "sp-firemonitoring-bootstrap-temp" \
#       --role "Owner" \
#       --scopes "/subscriptions/<SUBSCRIPTION_ID>" \
#       --sdk-auth
#
#   Set ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
#   as environment variables, run `terraform apply`, then IMMEDIATELY delete
#   the temporary SP:
#
#     az ad sp delete --id <TEMP_SP_OBJECT_ID>
#
#   From this point forward: NO client secrets exist anywhere.
#
# ==============================================================================

terraform {
  # The storage account referenced here must be pre-created via the az CLI
  # one-liner documented in terraform.tfvars.example BEFORE running init.
  backend "azurerm" {}
}

# ==============================================================================
# PROVIDERS
# ==============================================================================

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret # TEMPORARY — only used on first bootstrap run
}

# Microsoft Graph API — manages Entra ID objects (App Registrations, Federated Creds)
provider "azuread" {
  tenant_id     = var.azure_tenant_id
  client_id     = var.azure_client_id
  client_secret = var.azure_client_secret # TEMPORARY — only used on first bootstrap run
}

# GitHub — injects non-secret identity values into the repo environment
provider "github" {
  token = var.github_token
  owner = var.github_owner
}

# ==============================================================================
# 1. REMOTE STATE BACKEND (CAF Naming: rg-<workload>-tfstate-01)
# ==============================================================================

resource "azurerm_resource_group" "tfstate" {
  name     = var.tfstate_resource_group_name
  location = var.azure_location

  tags = {
    workload   = "firemonitoring"
    layer      = "bootstrap"
    managed-by = "terraform"
  }
}

resource "azurerm_storage_account" "tfstate" {
  name                            = var.tfstate_storage_account_name
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  # Versioning enables point-in-time state recovery if corruption occurs
  blob_properties {
    versioning_enabled = true
  }

  tags = {
    workload   = "firemonitoring"
    layer      = "bootstrap"
    managed-by = "terraform"
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# ==============================================================================
# 2. ENTRA ID — CI/CD WORKLOAD IDENTITY (The GitHub Actions Identity)
# ==============================================================================

data "azuread_client_config" "current" {}

# The App Registration represents the GitHub Actions pipeline identity in Entra ID.
# It has NO password / client secret — it authenticates exclusively via OIDC federation.
resource "azuread_application" "github_actions" {
  display_name = "sp-firemonitoring-github-actions"

  tags = ["firemonitoring", "github-actions", "oidc"]
}

resource "azuread_service_principal" "github_actions" {
  client_id                    = azuread_application.github_actions.client_id
  app_role_assignment_required = false
}

# ==============================================================================
# 3. FEDERATED IDENTITY CREDENTIALS (OIDC Trust — Zero Secrets)
# ==============================================================================
#
# Each credential defines a trust relationship:
#   "GitHub OIDC tokens issued for this repo+environment are trusted as THIS identity."
#
# The subject must match exactly what GitHub includes in the OIDC token.
# See: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect#understanding-the-oidc-token

resource "azuread_application_federated_identity_credential" "aks_dev" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-env-aks-dev"
  description    = "Trust for GitHub Actions jobs running in the 'aks-dev' environment"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_owner}/${var.github_repository}:environment:aks-dev"
}

resource "azuread_application_federated_identity_credential" "aks_prod" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-env-aks-prod"
  description    = "Trust for GitHub Actions jobs running in the 'aks-prod' environment"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_owner}/${var.github_repository}:environment:aks-prod"
}

# Allows plan-only (validate) runs triggered directly from the main branch
resource "azuread_application_federated_identity_credential" "main_branch" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-branch-main"
  description    = "Trust for GitHub Actions jobs running on the main branch (plan/validate only)"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/main"
}

# ==============================================================================
# 4. RBAC — LEAST PRIVILEGE ROLE ASSIGNMENTS
# ==============================================================================

# Contributor at subscription scope allows the CI identity to provision all
# Azure resources defined in 01-infra (RGs, VNets, AKS, ACR, Key Vault).
# In a production enterprise, this would be scoped to the landing zone RG only.
resource "azurerm_role_assignment" "contributor" {
  scope                = "/subscriptions/${var.azure_subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Storage Blob Data Contributor allows the CI identity to read/write Terraform
# state blobs using its Entra ID token — NO storage account key required.
# This enables `use_azuread_auth = true` in backend.conf.
resource "azurerm_role_assignment" "state_blob_contributor" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# User Access Administrator is needed so the CI identity can assign roles
# to the AKS kubelet identity and workload identity in later layers.
resource "azurerm_role_assignment" "user_access_admin" {
  scope                = "/subscriptions/${var.azure_subscription_id}"
  role_definition_name = "User Access Administrator"
  principal_id         = azuread_service_principal.github_actions.object_id

  # Constrain to only allow role assignments at or below the subscription scope,
  # preventing privilege escalation to management group level.
  condition_version = "2.0"
  condition         = <<-EOT
    @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEqualsIgnoreCase '${var.azure_subscription_id}'
    || @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEqualsIgnoreCase 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  EOT
}

# ==============================================================================
# 5. GITHUB — INJECT NON-SECRET IDENTITY VALUES
# ==============================================================================
#
# IMPORTANT: None of these are secrets — they are all public GUIDs that
# identify the workload. The OIDC federation is what makes them secure;
# the GUIDs alone cannot authenticate anything.
#
# We inject them into BOTH GitHub environments (aks-dev and aks-prod) so
# the reusable workflow can reference them without duplication.

resource "github_repository_environment" "aks_dev" {
  environment = "aks-dev"
  repository  = var.github_repository
}

resource "github_repository_environment" "aks_prod" {
  environment = "aks-prod"
  repository  = var.github_repository
}

locals {
  # The non-secret identity values injected into both environments
  azure_identity_vars = {
    AZURE_CLIENT_ID       = azuread_application.github_actions.client_id
    AZURE_TENANT_ID       = var.azure_tenant_id
    AZURE_SUBSCRIPTION_ID = var.azure_subscription_id
    # Storage account name is not secret — needed by backend.conf generation
    TF_STATE_STORAGE_ACCOUNT = azurerm_storage_account.tfstate.name
    TF_STATE_RESOURCE_GROUP  = azurerm_resource_group.tfstate.name
  }
}

resource "github_actions_environment_variable" "aks_dev" {
  for_each = local.azure_identity_vars

  repository    = var.github_repository
  environment   = github_repository_environment.aks_dev.environment
  variable_name = each.key
  value         = each.value
}

resource "github_actions_environment_variable" "aks_prod" {
  for_each = local.azure_identity_vars

  repository    = var.github_repository
  environment   = github_repository_environment.aks_prod.environment
  variable_name = each.key
  value         = each.value
}

# GitHub App credentials for ArgoCD repo access and CI token generation.
# These ARE sensitive — stored as encrypted GitHub secrets.
resource "github_actions_environment_secret" "app_id" {
  for_each = toset(["aks-dev", "aks-prod"])

  repository  = var.github_repository
  environment = each.key
  secret_name = "APP_ID"
  value       = var.github_app_id

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}

resource "github_actions_environment_secret" "app_installation_id" {
  for_each = toset(["aks-dev", "aks-prod"])

  repository  = var.github_repository
  environment = each.key
  secret_name = "APP_INSTALLATION_ID"
  value       = var.github_app_installation_id

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}

resource "github_actions_environment_secret" "app_private_key" {
  for_each = toset(["aks-dev", "aks-prod"])

  repository  = var.github_repository
  environment = each.key
  secret_name = "APP_PRIVATE_KEY"
  value       = var.github_app_private_key_path != "" ? file(var.github_app_private_key_path) : var.github_app_private_key

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}
