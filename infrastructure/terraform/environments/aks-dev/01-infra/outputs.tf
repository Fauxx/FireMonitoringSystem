output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "cluster_name" {
  value = module.aks.cluster_name
}

output "cluster_endpoint" {
  value     = module.aks.cluster_endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = module.aks.cluster_ca_certificate
  sensitive = true
}

output "oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  value = module.aks.kubelet_identity_object_id
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "acr_id" {
  value = azurerm_container_registry.main.id
}

output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}
