# ==============================================================================
# Outputs for Azure Dev 01-Infra
# ==============================================================================

output "resource_group_name" {
  description = "The name of the resource group holding the AKS cluster."
  value       = azurerm_resource_group.this.name
}

output "cluster_id" {
  description = "The ID of the Kubernetes cluster."
  value       = module.aks_cluster.cluster_id
}

output "cluster_name" {
  description = "The human-readable name of the AKS cluster passed to Layer 2."
  value       = module.aks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "The API endpoint (host) for the Kubernetes cluster."
  value       = module.aks_cluster.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "The base64 encoded CA certificate for the Kubernetes cluster."
  value       = module.aks_cluster.cluster_ca_certificate
  sensitive   = true
}

output "kubeconfig_raw" {
  description = "The raw kubeconfig for the fire monitoring cluster."
  value       = module.aks_cluster.kubeconfig_raw
  sensitive   = true
}

output "vnet_id" {
  description = "The ID of the Virtual Network."
  value       = azurerm_virtual_network.this.id
}

output "subnet_id" {
  description = "The ID of the Subnet used by AKS."
  value       = azurerm_subnet.aks.id
}
