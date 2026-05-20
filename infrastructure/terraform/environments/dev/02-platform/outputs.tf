output "argocd_loadbalancer_ip" {
  value       = data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].ip
  description = "The public external LoadBalancer IP assigned to your cluster's ArgoCD management gate."
}

output "argocd_namespace" {
  value       = kubernetes_namespace.argocd.metadata[0].name
  description = "The isolated namespace hosting the active GitOps deployment mechanics."
}

output "argocd_url" {
  value       = "https://${digitalocean_record.argocd.fqdn}"
  description = "The public DNS URL mapped to your live ArgoCD interface control room."
}