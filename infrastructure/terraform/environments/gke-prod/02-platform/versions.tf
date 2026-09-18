terraform {
  required_version = ">= 1.11.0"
  required_providers {
    google = { 
      source = "hashicorp/google"
      version = "~> 6.0" 
    }
    kubernetes = { 
      source = "hashicorp/kubernetes"
      version = "~> 2.35.0" 
    }
    helm = { 
      source = "hashicorp/helm"
      version = "~> 2.15.0" 
    }
  }
  backend "gcs" {}
}
provider "google" {}
