# ==============================================================================
# Outputs for Azure DNS Module
# ==============================================================================

output "dns_zone_name" {
  description = "The name of the DNS zone."
  value       = azurerm_dns_zone.this.name
}

output "dns_zone_id" {
  description = "The ID of the DNS zone."
  value       = azurerm_dns_zone.this.id
}

output "name_servers" {
  description = "The Azure DNS nameservers to delegate at registrar."
  value       = azurerm_dns_zone.this.name_servers
}
