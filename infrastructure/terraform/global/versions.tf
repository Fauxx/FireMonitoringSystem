terraform {
  required_version = "~> 1.11.0" # Allows 1.11.0 up to 1.11.x patches, but not 1.12.0 or later
  
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