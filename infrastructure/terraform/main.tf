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
