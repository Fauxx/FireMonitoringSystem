output "argocd_app_name" {
  description = "Name of the master ArgoCD Application-of-Applications manager."
  value       = kubernetes_manifest.argocd_apps.manifest.metadata.name
}

output "gitops_target_branch" {
  description = "The active git repository branch tracked by the engine loop."
  value       = var.gitops_repo_branch
}

output "gitops_target_path" {
  description = "The target file directory parsed inside your FireMonitoringSystem repo."
  value       = var.gitops_repo_apps_path
}