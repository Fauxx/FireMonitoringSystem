output "environment" {
  value = "dev"
}

output "deploy_host_ip" {
  description = "The actual IP address to be used for GitHub Actions and SSH"
  value       = module.compute.ipv4_address
}

output "droplet_ids" {
  value = [module.compute.id]
}

output "firewall_id" {
  value = module.networking.id
}

