output "github_actions_client_id" {
  value       = data.azuread_application.github_actions.client_id
  description = "The client ID of the shared GitHub Actions SP."
}

output "federated_subjects" {
  value       = "Managed primarily in aks-dev/00-bootstrap"
  description = "Info"
}
