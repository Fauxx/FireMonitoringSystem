output "tfstate_resource_group_name" {
  description = "The CAF-named Resource Group holding the Terraform state storage account."
  value       = azurerm_resource_group.tfstate.name
}

output "tfstate_storage_account_name" {
  description = "The CAF-named Storage Account holding all Terraform state blobs."
  value       = azurerm_storage_account.tfstate.name
}

output "tfstate_container_name" {
  description = "The blob container name within the storage account."
  value       = azurerm_storage_container.tfstate.name
}

output "github_actions_client_id" {
  description = "The Client ID (App ID) of the GitHub Actions Entra ID App Registration. NOT a secret — this is the OIDC identity reference."
  value       = azuread_application.github_actions.client_id
}

output "github_actions_sp_object_id" {
  description = "The Object ID of the GitHub Actions Service Principal (for RBAC assignments in later layers)."
  value       = azuread_service_principal.github_actions.object_id
}

output "federated_credential_subjects" {
  description = "The OIDC subject claims registered for this workload identity."
  value = {
    aks_dev     = azuread_application_federated_identity_credential.aks_dev.subject
    aks_prod    = azuread_application_federated_identity_credential.aks_prod.subject
    main_branch = azuread_application_federated_identity_credential.main_branch.subject
  }
}
