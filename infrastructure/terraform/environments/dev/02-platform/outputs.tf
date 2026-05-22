# ==============================================================================
# PLATFORM LAYER MECHANICS ENGINE OUTPUTS (02-PLATFORM)
# ==============================================================================

output "argocd_loadbalancer_ip" {
  # ALIGNED: Points to the updated data.kubernetes_service_v1 source
  value       = data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].ip
  description = "The public external LoadBalancer IP assigned to your cluster's ArgoCD management gate."
}

output "argocd_namespace" {
  # FIXED: Updated resource block name from kubernetes_namespace to kubernetes_namespace_v1
  value       = kubernetes_namespace_v1.argocd.metadata[0].name
  description = "The isolated namespace hosting the active GitOps deployment mechanics."
}

output "argocd_url" {
  value       = "https://${digitalocean_record.argocd.fqdn}"
  description = "The public DNS URL mapped to your live ArgoCD interface control room."
}