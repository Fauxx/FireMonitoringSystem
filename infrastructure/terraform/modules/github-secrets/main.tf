terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.12.0"
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
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "APP_ID"
  value       = var.github_app_id

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}

resource "github_actions_environment_secret" "github_app_installation_id" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "APP_INSTALLATION_ID"
  value       = var.github_app_installation_id

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}

resource "github_actions_environment_secret" "github_app_private_key" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "APP_PRIVATE_KEY"
  value       = var.github_app_private_key

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}

resource "github_actions_environment_secret" "github_app_state_access_key" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "TF_STATE_ACCESS_KEY"
  value       = var.github_app_state_access_key

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}

resource "github_actions_environment_secret" "github_app_state_secret_key" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "TF_STATE_SECRET_KEY"
  value       = var.github_app_state_secret_key

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}

resource "github_actions_environment_secret" "do_token" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "DO_TOKEN"
  value       = var.do_token

  lifecycle {
    ignore_changes = [value, encrypted_value]
  }
}

# ==============================================================================
# 3. ENVIRONMENT VARIABLES (Non-Sensitive)
# ==============================================================================

resource "github_actions_environment_variable" "root_domain" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "ROOT_DOMAIN"
  value         = var.root_domain
}

resource "github_actions_environment_variable" "cluster_name" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "CLUSTER_NAME"
  value         = var.cluster_name
}

resource "github_actions_environment_variable" "node_size" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "NODE_SIZE"
  value         = var.node_size
}

resource "github_actions_environment_variable" "node_count" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "NODE_COUNT"
  value         = tostring(var.node_count)
}

resource "github_actions_environment_variable" "remote_state_bucket" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "REMOTE_STATE_BUCKET"
  value         = var.remote_state_bucket
}

resource "github_actions_environment_variable" "infra_state_key" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "INFRA_STATE_KEY"
  value         = var.infra_state_key
}

resource "github_actions_environment_variable" "gitops_repo_url" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "GITOPS_REPO_URL"
  value         = var.gitops_repo_url
}



