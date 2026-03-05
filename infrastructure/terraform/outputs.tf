output "droplet_ips" {
  description = "Public IPv4 addresses for all fire-monitoring droplets"
  value       = [for d in digitalocean_droplet.fire_core : d.ipv4_address]
}

