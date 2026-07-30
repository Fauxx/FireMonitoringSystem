# This layer uses data sources for the shared OIDC identity created in aks-dev/00-bootstrap. 
# Run aks-dev bootstrap first.

terraform {
  backend "azurerm" {}
}

provider "azuread" {
  client_id     = var.azure_client_id
  client_secret = var.azure_client_secret
  tenant_id     = var.azure_tenant_id
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

data "azuread_application" "github_actions" {
  display_name = "sp-firemonitoring-github-actions"
}

data "azuread_service_principal" "github_actions" {
  client_id = data.azuread_application.github_actions.client_id
}

resource "github_repository_environment" "aks_prod" {
  repository  = var.github_repository
  environment = "aks-prod"
}

# Provide the necessary variables to the prod environment
resource "github_actions_environment_variable" "azure_client_id" {
  repository    = var.github_repository
  environment   = github_repository_environment.aks_prod.environment
  variable_name = "AZURE_CLIENT_ID"
  value         = data.azuread_application.github_actions.client_id
}

resource "github_actions_environment_variable" "azure_tenant_id" {
  repository    = var.github_repository
  environment   = github_repository_environment.aks_prod.environment
  variable_name = "AZURE_TENANT_ID"
  value         = var.azure_tenant_id
}

resource "github_actions_environment_variable" "azure_subscription_id" {
  repository    = var.github_repository
  environment   = github_repository_environment.aks_prod.environment
  variable_name = "AZURE_SUBSCRIPTION_ID"
  value         = var.azure_subscription_id
}

resource "github_actions_environment_variable" "tf_state_resource_group" {
  repository    = var.github_repository
  environment   = github_repository_environment.aks_prod.environment
  variable_name = "TF_STATE_RESOURCE_GROUP"
  value         = var.tfstate_resource_group
}

resource "github_actions_environment_variable" "tf_state_storage_account" {
  repository    = var.github_repository
  environment   = github_repository_environment.aks_prod.environment
  variable_name = "TF_STATE_STORAGE_ACCOUNT"
  value         = var.tfstate_storage_account
}

resource "github_actions_environment_secret" "app_id" {
  repository      = var.github_repository
  environment     = github_repository_environment.aks_prod.environment
  secret_name     = "APP_ID"
  plaintext_value = var.github_app_id
}

resource "github_actions_environment_secret" "app_installation_id" {
  repository      = var.github_repository
  environment     = github_repository_environment.aks_prod.environment
  secret_name     = "APP_INSTALLATION_ID"
  plaintext_value = var.github_app_installation_id
}

resource "github_actions_environment_secret" "app_private_key" {
  repository      = var.github_repository
  environment     = github_repository_environment.aks_prod.environment
  secret_name     = "APP_PRIVATE_KEY"
  plaintext_value = var.github_app_private_key_path != "" ? file(var.github_app_private_key_path) : var.github_app_private_key
}

resource "azuread_application_federated_identity_credential" "github_actions_prod" {
  application_id = data.azuread_application.github_actions.id
  display_name   = "github-actions-aks-prod"
  description    = "Deploy from GitHub Actions for aks-prod environment"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_owner}/${var.github_repository}:environment:aks-prod"

  # Prevent failure if already created in dev layer or elsewhere
  lifecycle {
    ignore_changes = all
  }
}
