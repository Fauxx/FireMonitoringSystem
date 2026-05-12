terraform {
  required_version = ">= 1.5.0"

  backend "s3" {}

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.40.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_kubernetes_versions" "this" {}

locals {
  environment = "dev"
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = digitalocean_kubernetes_cluster.this.name
    clusters = [
      {
        name = digitalocean_kubernetes_cluster.this.name
        cluster = {
          server                     = digitalocean_kubernetes_cluster.this.endpoint
          certificate-authority-data = digitalocean_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
        }
      }
    ]
    contexts = [
      {
        name = digitalocean_kubernetes_cluster.this.name
        context = {
          cluster = digitalocean_kubernetes_cluster.this.name
          user    = digitalocean_kubernetes_cluster.this.name
        }
      }
    ]
    users = [
      {
        name = digitalocean_kubernetes_cluster.this.name
        user = {
          token = digitalocean_kubernetes_cluster.this.kube_config[0].token
        }
      }
    ]
  })
}

resource "digitalocean_kubernetes_cluster" "this" {
  name    = "fire-monitoring-${local.environment}"
  region  = var.region
  version = var.doks_version != "" ? var.doks_version : data.digitalocean_kubernetes_versions.this.latest_version

  node_pool {
    name       = "default-pool"
    size       = var.doks_node_size
    node_count = var.doks_node_count
    tags       = ["fire-monitoring", "iot", local.environment]
  }
}
