terraform {
  required_version = ">= 1.11.0" # Allows 1.11.0 and any newer version (e.g. 1.15.x)

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.47.0" # Lock it to a specific minor release family to avoid breaking API updates
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15.0"
    }
  }
}