terraform {
  required_version = ">= 1.5.0"

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

variable "do_token" {
  description = "DigitalOcean access token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Region for all resources"
  type        = string
  default     = "sgp1"
}

resource "digitalocean_droplet" "fire_core" {
  count  = var.instance_count
  name   = "fire-monitoring-${count.index}"
  region = var.region
  size   = var.droplet_size
  image  = var.droplet_image
  tags   = ["fire-monitoring", "iot"]

  ssh_keys = var.ssh_key_ids
}

variable "instance_count" {
  description = "Number of droplets to create"
  type        = number
  default     = 1
}

variable "droplet_size" {
  description = "Droplet size slug"
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "droplet_image" {
  description = "Droplet image slug"
  type        = string
  default     = "docker-20-04"
}

variable "ssh_key_ids" {
  description = "List of SSH key IDs uploaded to DigitalOcean"
  type        = list(string)
  default     = []
}

variable "deploy_host_ip" {
  description = "Canonical SSH host IP used by deployment automation"
  type        = string
  default     = "129.212.238.200"
}
