output "droplet_ips" {
  description = "Public IPv4 addresses for all fire-monitoring droplets"
  value       = digitalocean_droplet.fire_core[*].ipv4_address
}

output "deploy_host_ip" {
  description = "The actual IP address to be used for GitHub Actions and SSH"
  value       = digitalocean_droplet.fire_core[0].ipv4_address
}