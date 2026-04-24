terraform {
  required_version = ">= 1.5.0"

  backend "s3" {}

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.40.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

locals {
  environment           = "dev"
  github_environment    = "development"
  droplet_name          = "fire-monitoring-dev"
  firewall_name         = "fire-monitoring-dev-firewall"
  manage_github_secrets = length(trimspace(var.github_token)) > 0 && length(trimspace(var.github_repo)) > 0
}

module "compute" {
  source      = "../../modules/compute"
  name        = local.droplet_name
  region      = var.region
  size        = var.droplet_size
  image       = var.droplet_image
  tags        = ["fire-monitoring", "iot", local.environment]
  ssh_key_ids = var.ssh_key_ids
}

module "networking" {
  source          = "../../modules/networking"
  name            = local.firewall_name
  droplet_ids     = [module.compute.id]
  allow_ssh_cidrs = var.allow_ssh_cidrs
}

module "github_secrets" {
  source                  = "../../modules/github-secrets"
  enabled                 = local.manage_github_secrets
  github_repo             = var.github_repo
  github_environment      = local.github_environment
  do_ssh_host             = module.compute.ipv4_address
  do_ssh_host_fingerprint = var.do_ssh_host_fingerprint
}

module "storage" {
  source  = "../../modules/storage"
  enabled = false
}

