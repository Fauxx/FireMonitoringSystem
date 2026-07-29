# ==============================================================================
# PLATFORM LAYER MECHANICS ENGINE OUTPUTS (02-PLATFORM)
# ==============================================================================

output "load_balancer_ip" {
  value       = module.ingress_controller.load_balancer_ip
  description = "The external IP address of the provisioned ingress controller load balancer."
}

output "argocd_namespace" {
  value       = kubernetes_namespace_v1.argocd.metadata[0].name
  description = "The isolated namespace hosting the active GitOps deployment mechanics."
}

output "fire_monitoring_namespace" {
  value       = kubernetes_namespace_v1.fire_monitoring_azure_dev.metadata[0].name
  description = "The namespace for the fire monitoring dev application."
}

output "dns_zone_name" {
  value       = var.dns_zone_name
  description = "The Azure DNS zone name."
}

output "dns_nameservers" {
  value       = module.azure_dns.name_servers
  description = "IMPORTANT: The name servers for the Azure DNS zone. You must update your registrar to point to these name servers."
}
