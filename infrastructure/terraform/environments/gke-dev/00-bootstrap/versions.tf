terraform {
  required_version = ">= 1.11.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.12.0"
    }
  }
  backend "gcs" {}
}

provider "google" {
  project = var.gcp_project_id
  region  = var.region
}

provider "github" {
  owner = "Fauxx"
  token = var.github_token
}
