terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

resource "digitalocean_droplet" "this" {
  name     = var.name
  region   = var.region
  size     = var.size
  image    = var.image
  tags     = var.tags
  ssh_keys = var.ssh_key_ids
}

