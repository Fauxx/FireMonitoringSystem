terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
  }
}

# 1. ADD THIS: This creates the environment folder in GitHub
resource "github_repository_environment" "this" {
  count       = var.enabled ? 1 : 0
  repository  = var.github_repo
  environment = var.github_environment # "development"
}

# 2. UPDATE THESE: Link them to the resource above
resource "github_actions_environment_secret" "do_ssh_host" {
  count           = var.enabled ? 1 : 0
  repository      = var.github_repo
  # Use the reference to the environment resource to force the dependency
  environment     = github_repository_environment.this[0].environment
  secret_name     = "DO_SSH_HOST"
  value           = var.do_ssh_host # Changed to 'value'

  depends_on = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "do_ssh_fingerprint" {
  count           = var.enabled ? 1 : 0
  repository      = var.github_repo
  environment     = github_repository_environment.this[0].environment
  secret_name     = "DO_SSH_FINGERPRINT"
  value           = var.do_ssh_host_fingerprint

  depends_on = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "do_ssh_port" {
  count           = var.enabled ? 1 : 0
  repository      = var.github_repo
  environment     = github_repository_environment.this[0].environment
  secret_name     = "DO_SSH_PORT"
  value           = var.do_ssh_port

  depends_on = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "do_ssh_user" {
  count           = var.enabled ? 1 : 0
  repository      = var.github_repo
  environment     = github_repository_environment.this[0].environment
  secret_name     = "DO_SSH_USER"
  value           = var.do_ssh_user

  depends_on = [github_repository_environment.this]
}