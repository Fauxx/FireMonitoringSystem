output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_url" {
  value = "https://argocd.fires.systems"
}

output "argocd_loadbalancer_ip" {
  value = data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].ip
}