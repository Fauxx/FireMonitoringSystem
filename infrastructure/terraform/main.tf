terraform {
  required_version = ">= 1.5.0"
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

# --- Providers ---

provider "digitalocean" {
  token = var.do_token
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

# --- Variables ---

variable "do_token" {
  type      = string
  sensitive = true

  validation {
    condition     = length(trimspace(var.do_token)) > 0 && !startswith(var.do_token, "PASTE_")
    error_message = "Set do_token to a real DigitalOcean PAT (not a placeholder)."
  }
}

variable "github_token" {
  type      = string
  sensitive = true

  validation {
    condition     = length(trimspace(var.github_token)) > 0 && !startswith(var.github_token, "PASTE_")
    error_message = "Set github_token to a real GitHub PAT (not a placeholder)."
  }
}

variable "github_owner" {
  type = string

  validation {
    condition     = length(trimspace(var.github_owner)) > 0 && !startswith(var.github_owner, "PASTE_")
    error_message = "Set github_owner to your real GitHub username or organization (not a placeholder)."
  }
}

variable "github_repo" {
  type = string
}

variable "ssh_key_ids" {
  type = list(string)

  validation {
    condition = (
      length(var.ssh_key_ids) > 0 &&
      length(compact(var.ssh_key_ids)) == length(var.ssh_key_ids) &&
      length([for id in var.ssh_key_ids : id if startswith(id, "PASTE_")]) == 0
    )
    error_message = "Set ssh_key_ids to real DigitalOcean SSH key IDs/fingerprints from your account."
  }
}

variable "do_ssh_host_fingerprint" {
  type = string

  validation {
    condition     = length(trimspace(var.do_ssh_host_fingerprint)) > 0 && startswith(var.do_ssh_host_fingerprint, "SHA256:") && !strcontains(var.do_ssh_host_fingerprint, "PASTE_")
    error_message = "Set do_ssh_host_fingerprint to the real server host key fingerprint in SHA256 format (e.g., SHA256:...)."
  }
}

variable "region"        { default = "sgp1" }
variable "droplet_size"  { default = "s-1vcpu-2gb" }
variable "droplet_image" { default = "docker-20-04" }

# --- Resources: DigitalOcean ---

resource "digitalocean_droplet" "fire_core" {
  count    = 1
  name     = "fire-monitoring-prod"
  region   = var.region
  size     = var.droplet_size
  image    = var.droplet_image
  tags     = ["fire-monitoring", "iot"]
  ssh_keys = var.ssh_key_ids
}

resource "digitalocean_firewall" "fire_monitoring_fw" {
  name        = "fire-monitoring-firewall"
  droplet_ids = digitalocean_droplet.fire_core[*].id

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# --- Resources: GitHub Secrets Automation ---

resource "github_actions_secret" "do_ssh_host" {
  repository      = var.github_repo
  secret_name     = "DO_SSH_HOST"
  plaintext_value = digitalocean_droplet.fire_core[0].ipv4_address
}

resource "github_actions_secret" "do_ssh_fingerprint" {
  repository      = var.github_repo
  secret_name     = "DO_SSH_FINGERPRINT"
  plaintext_value = var.do_ssh_host_fingerprint
}

# Optional: Adding these ensures GitHub always has the right Port/User
resource "github_actions_secret" "do_ssh_port" {
  repository      = var.github_repo
  secret_name     = "DO_SSH_PORT"
  plaintext_value = "22"
}

resource "github_actions_secret" "do_ssh_user" {
  repository      = var.github_repo
  secret_name     = "DO_SSH_USER"
  plaintext_value = "root"
}