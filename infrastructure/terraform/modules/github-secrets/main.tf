terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
  }
}

resource "github_actions_secret" "do_ssh_host" {
  count           = var.enabled ? 1 : 0
  repository      = var.github_repo
  secret_name     = "DO_SSH_HOST"
  plaintext_value = var.do_ssh_host
}

resource "github_actions_secret" "do_ssh_fingerprint" {
  count           = var.enabled ? 1 : 0
  repository      = var.github_repo
  secret_name     = "DO_SSH_FINGERPRINT"
  plaintext_value = var.do_ssh_host_fingerprint
}

resource "github_actions_secret" "do_ssh_port" {
  count           = var.enabled ? 1 : 0
  repository      = var.github_repo
  secret_name     = "DO_SSH_PORT"
  plaintext_value = var.do_ssh_port
}

resource "github_actions_secret" "do_ssh_user" {
  count           = var.enabled ? 1 : 0
  repository      = var.github_repo
  secret_name     = "DO_SSH_USER"
  plaintext_value = var.do_ssh_user
}

