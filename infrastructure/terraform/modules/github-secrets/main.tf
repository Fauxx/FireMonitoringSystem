terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# ==============================================================================
# 1. ENVIRONMENT CONTAINER PLATFORM
# ==============================================================================

resource "github_repository_environment" "this" {
  environment         = var.github_environment
  repository          = var.github_repository
  prevent_self_review = false
}

# ==============================================================================
# 2. ENCRYPTED VALIDATION SECRETS VAULT
# ==============================================================================

resource "github_actions_environment_secret" "github_app_id" {
  repository      = var.github_repository
  environment     = github_repository_environment.this.environment
  secret_name     = "APP_ID"
  value           = var.github_app_id
}

resource "github_actions_environment_secret" "github_app_installation_id" {
  repository      = var.github_repository
  environment     = github_repository_environment.this.environment
  secret_name     = "APP_INSTALLATION_ID"
  value           = var.github_app_installation_id
}

resource "github_actions_environment_secret" "github_app_private_key" {
  repository      = var.github_repository
  environment     = github_repository_environment.this.environment
  secret_name     = "APP_PRIVATE_KEY"
  value           = var.github_app_private_key
}

resource "github_actions_environment_secret" "github_app_state_access_key" {
  repository      = var.github_repository
  environment     = github_repository_environment.this.environment
  secret_name     = "TF_STATE_ACCESS_KEY"
  value           = var.github_app_state_access_key
}

resource "github_actions_environment_secret" "github_app_state_secret_key" {
  repository      = var.github_repository
  environment     = github_repository_environment.this.environment
  secret_name     = "TF_STATE_SECRET_KEY"
  value           = var.github_app_state_secret_key
}


