locals {
  manage_github_secrets = length(trimspace(var.github_token)) > 0 && length(trimspace(var.github_repo)) > 0
}

resource "github_actions_secret" "do_ssh_host" {
  count           = local.manage_github_secrets ? 1 : 0
  repository      = var.github_repo
  secret_name     = "DO_SSH_HOST"
  plaintext_value = digitalocean_droplet.fire_core[0].ipv4_address
}

resource "github_actions_secret" "do_ssh_fingerprint" {
  count           = local.manage_github_secrets ? 1 : 0
  repository      = var.github_repo
  secret_name     = "DO_SSH_FINGERPRINT"
  plaintext_value = var.do_ssh_host_fingerprint
}

resource "github_actions_secret" "do_ssh_port" {
  count           = local.manage_github_secrets ? 1 : 0
  repository      = var.github_repo
  secret_name     = "DO_SSH_PORT"
  plaintext_value = "22"
}

resource "github_actions_secret" "do_ssh_user" {
  count           = local.manage_github_secrets ? 1 : 0
  repository      = var.github_repo
  secret_name     = "DO_SSH_USER"
  plaintext_value = "root"
}
