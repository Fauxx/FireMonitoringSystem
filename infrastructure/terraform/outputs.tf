output "droplet_ips" {
  description = "Public IPv4 addresses for all fire-monitoring droplets"
  value       = [for d in digitalocean_droplet.fire_core : d.ipv4_address]
}

output "deploy_host_ip" {
  description = "Canonical host IP for SSH-based deploy workflows"
  value       = var.deploy_host_ip
}
