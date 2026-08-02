# ==============================================================================
# shared/github-secrets — OIDC-Aligned GitHub Environment Module
# ==============================================================================
#
# Provisions a GitHub Actions environment with the correct variable and secret
# configuration for OIDC-based Azure authentication.
#
# IMPORTANT: This module injects NON-SECRET identity GUIDs as environment
# VARIABLES (not secrets) and stores only genuinely sensitive values
# (GitHub App keys) as encrypted secrets.
#
# No AZURE_CLIENT_SECRET is injected — OIDC tokens replace long-lived credentials.
# ==============================================================================

terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.12.0"
    }
  }
}

# ==============================================================================
# GITHUB ENVIRONMENT
# ==============================================================================

resource "github_repository_environment" "this" {
  environment         = var.github_environment
  repository          = var.github_repository
  prevent_self_review = false
}

# ==============================================================================
# AZURE IDENTITY VARIABLES (Non-Sensitive — GUIDs only)
# These are safe to store as environment variables, not secrets.
# They identify the workload but cannot authenticate alone.
# ==============================================================================

resource "github_actions_environment_variable" "azure_client_id" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "AZURE_CLIENT_ID"
  value         = var.azure_client_id
}

resource "github_actions_environment_variable" "azure_tenant_id" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "AZURE_TENANT_ID"
  value         = var.azure_tenant_id
}

resource "github_actions_environment_variable" "azure_subscription_id" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "AZURE_SUBSCRIPTION_ID"
  value         = var.azure_subscription_id
}

resource "github_actions_environment_variable" "tf_state_storage_account" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "TF_STATE_STORAGE_ACCOUNT"
  value         = var.tf_state_storage_account
}

resource "github_actions_environment_variable" "tf_state_resource_group" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "TF_STATE_RESOURCE_GROUP"
  value         = var.tf_state_resource_group
}

resource "github_actions_environment_variable" "gitops_repo_url" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "GITOPS_REPO_URL"
  value         = var.gitops_repo_url
}

# ==============================================================================
# GITHUB APP SECRETS (Sensitive — encrypted at rest in GitHub)
# Used for: CI token generation (actions/create-github-app-token)
#           and ArgoCD repository access
# ==============================================================================

resource "github_actions_environment_secret" "app_id" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "APP_ID"
  value       = var.github_app_id

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}

resource "github_actions_environment_secret" "app_installation_id" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "APP_INSTALLATION_ID"
  value       = var.github_app_installation_id

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}

resource "github_actions_environment_secret" "app_private_key" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "APP_PRIVATE_KEY"
  value       = var.github_app_private_key

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}
