output "github_environment" {
  description = "The name of the GitHub environment configured"
  value       = var.enabled ? var.github_environment : "none"
}

output "secrets_synced" {
  description = "List of core secrets successfully pushed"
  value = compact([
    var.enabled ? "KUBECONFIG_DATA" : "",
    var.enabled ? "DIGITALOCEAN_TOKEN" : "",
    local.create_argocd_server ? "ARGOCD_SERVER" : ""
  ])
}