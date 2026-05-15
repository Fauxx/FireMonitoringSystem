terraform {
  required_version = ">= 1.5.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0" # This allows flexibility to avoid specific buggy versions
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = ">= 6.0.0"
    }
  }
}