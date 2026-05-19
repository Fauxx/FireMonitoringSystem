terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
  }
}

# --- 1. Environment Creation ---
resource "github_repository_environment" "this" {
  count       = var.enabled ? 1 : 0
  repository  = var.github_repo
  environment = var.github_environment
}

# --- 2. Conditional Logic for Secret Creation ---
locals {
  create_ghcr_username         = var.enabled && length(trimspace(var.ghcr_deploy_username)) > 0
  create_ghcr_token            = var.enabled && length(trimspace(var.ghcr_deploy_token)) > 0
  create_github_app_id         = var.enabled && length(trimspace(var.github_app_id)) > 0
  create_github_app_key        = var.enabled && length(trimspace(var.github_app_private_key)) > 0
  create_github_app_install_id = var.enabled && length(trimspace(var.github_app_installation_id)) > 0
  create_argocd_server         = var.enabled && length(trimspace(var.argocd_server)) > 0
  create_argocd_token          = var.enabled && length(trimspace(var.argocd_auth_token)) > 0
}

# --- 3. Kubernetes Secrets (Essential) ---
resource "github_actions_environment_secret" "kubeconfig_data" {
  count           = var.enabled ? 1 : 0
  repository      = var.github_repo
  environment     = var.github_environment
  secret_name     = "KUBECONFIG_DATA"
  plaintext_value = var.kubeconfig
  depends_on      = [github_repository_environment.this]
}

# --- 4. DigitalOcean Secrets (Essential) ---
resource "github_actions_environment_secret" "do_token" {
  count           = var.enabled ? 1 : 0
  repository      = var.github_repo
  environment     = var.github_environment
  secret_name     = "DIGITALOCEAN_TOKEN"
  plaintext_value = var.do_token
  depends_on      = [github_repository_environment.this]
}

# --- 5. ArgoCD Secrets ---
resource "github_actions_environment_secret" "argocd_server" {
  count           = local.create_argocd_server ? 1 : 0
  repository      = var.github_repo
  environment     = var.github_environment
  secret_name     = "ARGOCD_SERVER"
  plaintext_value = var.argocd_server
  depends_on      = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "argocd_auth_token" {
  count           = local.create_argocd_token ? 1 : 0
  repository      = var.github_repo
  environment     = var.github_environment
  secret_name     = "ARGOCD_AUTH_TOKEN"
  plaintext_value = var.argocd_auth_token
  depends_on      = [github_repository_environment.this]
}

# --- 6. Registry Secrets (GHCR) ---
resource "github_actions_environment_secret" "ghcr_username" {
  count           = local.create_ghcr_username ? 1 : 0
  repository      = var.github_repo
  environment     = var.github_environment
  secret_name     = "GHCR_DEPLOY_USERNAME"
  plaintext_value = var.ghcr_deploy_username
  depends_on      = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "ghcr_token" {
  count           = local.create_ghcr_token ? 1 : 0
  repository      = var.github_repo
  environment     = var.github_environment
  secret_name     = "GHCR_DEPLOY_TOKEN"
  plaintext_value = var.ghcr_deploy_token
  depends_on      = [github_repository_environment.this]
}

# --- 7. GitHub App Secrets (optional) ---
resource "github_actions_environment_secret" "github_app_id" {
  count           = local.create_github_app_id ? 1 : 0
  repository      = var.github_repo
  environment     = var.github_environment
  secret_name     = "APP_ID"
  plaintext_value = var.github_app_id
  depends_on      = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "github_app_installation_id" {
  count           = local.create_github_app_install_id ? 1 : 0
  repository      = var.github_repo
  environment     = var.github_environment
  secret_name     = "APP_INSTALLATION_ID"
  plaintext_value = var.github_app_installation_id
  depends_on      = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "github_app_private_key" {
  count           = local.create_github_app_key ? 1 : 0
  repository      = var.github_repo
  environment     = var.github_environment
  secret_name     = "APP_PRIVATE_KEY"
  
  plaintext_value = replace(var.github_app_private_key, "\\n", "\n")
  
  depends_on      = [github_repository_environment.this]
}