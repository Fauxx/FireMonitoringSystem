# ==============================================================================
# Outputs for Azure Dev 00-Bootstrap
# ==============================================================================

output "resource_group_name" {
  description = "The name of the resource group holding the state storage."
  value       = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  description = "The globally unique name of the state storage account."
  value       = azurerm_storage_account.terraform_state.name
}

output "container_name" {
  description = "The name of the container used for storing terraform state."
  value       = azurerm_storage_container.tfstate.name
}
