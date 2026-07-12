# ==============================================================================
# 1. STATE & BACKEND PLUMBING (Uses common backend.conf at init)
# ==============================================================================
terraform {
  backend "s3" {}
}

# ------------------------------------------------------------------------------
# 2. PROVIDERS
# ------------------------------------------------------------------------------
provider "digitalocean" {
  token = var.do_token
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

# ------------------------------------------------------------------------------
# 3. STORAGE & SECRET PROVISIONING ENGINE
# ------------------------------------------------------------------------------

# Mount or maintain your central state storage bucket
resource "digitalocean_spaces_bucket" "terraform_state" {
  name          = var.state_bucket_name
  region        = var.state_bucket_region
  acl           = "private"
  force_destroy = true
}

# Core secret injection module to populate your GitHub Production Environment
module "github_secrets" {
  source = "../../../modules/github-secrets"

  github_environment          = var.github_environment
  github_repository           = var.github_repository
  github_app_id               = var.github_app_id
  github_app_installation_id  = var.github_app_installation_id
  github_app_private_key      = var.github_app_private_key
  github_app_state_access_key = var.github_app_state_access_key
  github_app_state_secret_key = var.github_app_state_secret_key
  do_token                    = var.do_token

  # New streamlined truth injection
  root_domain         = var.root_domain
  cluster_name        = var.cluster_name
  node_size           = var.node_size
  node_count          = var.node_count
  remote_state_bucket = var.remote_state_bucket
  infra_state_key     = var.infra_state_key
  gitops_repo_url     = var.gitops_repo_url
}

# ------------------------------------------------------------------------------
# 4. EXPORTED BASELINE OUTPUTS
# ------------------------------------------------------------------------------
output "state_bucket_name" {
  value       = digitalocean_spaces_bucket.terraform_state.name
  description = "The verified name of your active state bucket."
}

output "state_bucket_region" {
  value       = digitalocean_spaces_bucket.terraform_state.region
  description = "The physical region housing your infrastructure state artifacts."
}
