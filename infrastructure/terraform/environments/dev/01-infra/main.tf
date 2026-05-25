terraform {
  # Secure Remote State Storage in DO Spaces
  backend "s3" {}
}

provider "digitalocean" {
  token = var.do_token
}

# 1. DOMAIN DELEGATION
data "digitalocean_domain" "fire_systems" {
  name = var.root_domain
}

# 2. PRIVATE NETWORK (VPC)
data "digitalocean_vpc" "cluster_network" {
  name = "${var.cluster_name}-vpc"
}

# 3. PROVISION DOKS CLUSTER
resource "digitalocean_kubernetes_cluster" "this" {
  name   = var.cluster_name
  region = var.region
  # Stable version slug for SGP1 region as of May 2026
  version  = "1.35.5-do.0"
  vpc_uuid = data.digitalocean_vpc.cluster_network.id

  node_pool {
    name       = "${var.cluster_name}-default-pool"
    size       = var.node_size
    node_count = var.node_count
  }
}