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
