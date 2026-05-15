output "argocd_app_name" {
  description = "Name of the ArgoCD Application (app-of-apps)"
  value       = kubernetes_manifest.argocd_apps.manifest.metadata.name
}

output "argocd_app_status" {
  description = "ArgoCD Application status"
  value       = "Check 'argocd app get apps' for current sync status"
}

output "gitops_repo_url" {
  description = "GitOps repository URL"
  value       = var.gitops_repo_url
}
