terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
  }
}

resource "github_repository_environment" "this" {
  count       = var.enabled ? 1 : 0
  repository  = var.github_repo
  environment = var.github_environment
}

locals {
  create_do_ssh_host        = var.enabled && length(trimspace(var.do_ssh_host)) > 0
  create_do_ssh_fingerprint = var.enabled && length(trimspace(var.do_ssh_host_fingerprint)) > 0
  create_do_ssh_port        = var.enabled && length(trimspace(var.do_ssh_port)) > 0
  create_do_ssh_user        = var.enabled && length(trimspace(var.do_ssh_user)) > 0
  create_do_ssh_private_key = var.enabled && length(trimspace(var.do_ssh_private_key)) > 0
  create_ghcr_username      = var.enabled && length(trimspace(var.ghcr_deploy_username)) > 0
  create_ghcr_token         = var.enabled && length(trimspace(var.ghcr_deploy_token)) > 0
}

resource "github_actions_environment_secret" "do_ssh_host" {
  count       = local.create_do_ssh_host ? 1 : 0
  repository  = var.github_repo
  environment = github_repository_environment.this[0].environment
  secret_name = "DO_SSH_HOST"
  value = var.do_ssh_host

  depends_on = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "do_ssh_fingerprint" {
  count       = local.create_do_ssh_fingerprint ? 1 : 0
  repository  = var.github_repo
  environment = github_repository_environment.this[0].environment
  secret_name = "DO_SSH_FINGERPRINT"
  value = var.do_ssh_host_fingerprint

  depends_on = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "do_ssh_port" {
  count       = local.create_do_ssh_port ? 1 : 0
  repository  = var.github_repo
  environment = github_repository_environment.this[0].environment
  secret_name = "DO_SSH_PORT"
  value = var.do_ssh_port

  depends_on = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "do_ssh_user" {
  count       = local.create_do_ssh_user ? 1 : 0
  repository  = var.github_repo
  environment = github_repository_environment.this[0].environment
  secret_name = "DO_SSH_USER"
  value = var.do_ssh_user

  depends_on = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "do_ssh_private_key" {
  count       = local.create_do_ssh_private_key ? 1 : 0
  repository  = var.github_repo
  environment = github_repository_environment.this[0].environment
  secret_name = "DO_SSH_PRIVATE_KEY"
  value = var.do_ssh_private_key

  depends_on = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "kubeconfig" {
  count       = var.enabled ? 1 : 0
  repository  = var.github_repo
  environment = github_repository_environment.this[0].environment
  secret_name = "KUBECONFIG"
  value = var.kubeconfig

  depends_on = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "ghcr_deploy_username" {
  count       = local.create_ghcr_username ? 1 : 0
  repository  = var.github_repo
  environment = github_repository_environment.this[0].environment
  secret_name = "GHCR_DEPLOY_USERNAME"
  value = var.ghcr_deploy_username

  depends_on = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "ghcr_deploy_token" {
  count       = local.create_ghcr_token ? 1 : 0
  repository  = var.github_repo
  environment = github_repository_environment.this[0].environment
  secret_name = "GHCR_DEPLOY_TOKEN"
  value = var.ghcr_deploy_token

  depends_on = [github_repository_environment.this]
}
