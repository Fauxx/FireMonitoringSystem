# ==============================================================================
# shared/github-secrets — OIDC-Aligned GitHub Environment Module (GCP)
# ==============================================================================
#
# Provisions a GitHub Actions environment with the correct variable and secret
# configuration for OIDC-based GCP authentication via Workload Identity Federation.
#
# No GCP service account keys are injected — WIF tokens replace long-lived credentials.
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
# GCP IDENTITY VARIABLES (Non-Sensitive — identifiers only)
# These identify the WIF provider and service account but cannot authenticate alone.
# ==============================================================================

resource "github_actions_environment_variable" "gcp_project_id" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "GCP_PROJECT_ID"
  value         = var.gcp_project_id
}

resource "github_actions_environment_variable" "gcp_workload_identity_provider" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "GCP_WORKLOAD_IDENTITY_PROVIDER"
  value         = var.gcp_workload_identity_provider
}

resource "github_actions_environment_variable" "gcp_service_account" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "GCP_SERVICE_ACCOUNT"
  value         = var.gcp_service_account
}

resource "github_actions_environment_variable" "tf_state_bucket" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "TF_STATE_BUCKET"
  value         = var.tf_state_bucket
}

resource "github_actions_environment_variable" "gitops_repo_url" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "GITOPS_REPO_URL"
  value         = var.gitops_repo_url
}

# ==============================================================================
# GITHUB APP SECRETS (Sensitive, encrypted at rest in GitHub)
# ==============================================================================

resource "github_actions_environment_secret" "app_id" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "APP_ID"
  value       = var.github_app_id
  lifecycle { ignore_changes = [value, encrypted_value] }
}

resource "github_actions_environment_secret" "app_installation_id" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "APP_INSTALLATION_ID"
  value       = var.github_app_installation_id
  lifecycle { ignore_changes = [value, encrypted_value] }
}

resource "github_actions_environment_secret" "app_private_key" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "APP_PRIVATE_KEY"
  value       = var.github_app_private_key
  lifecycle { ignore_changes = [value, encrypted_value] }
}

resource "github_actions_environment_secret" "cloudflare_tunnel_credentials" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "CLOUDFLARE_TUNNEL_CREDENTIALS_JSON"
  value       = var.cloudflare_tunnel_credentials_json
  lifecycle { ignore_changes = [value, encrypted_value] }
}
