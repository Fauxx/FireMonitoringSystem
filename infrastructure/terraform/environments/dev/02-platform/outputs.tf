# ==============================================================================
# PLATFORM LAYER MECHANICS ENGINE OUTPUTS (02-PLATFORM)
# ==============================================================================

# Output argocd_loadbalancer_ip and argocd_url removed as service is ClusterIP now.

output "argocd_namespace" {
  value       = kubernetes_namespace_v1.argocd.metadata[0].name
  description = "The isolated namespace hosting the active GitOps deployment mechanics."
}

output "ingress_loadbalancer_ip" {
  value       = module.ingress_controller.load_balancer_ip
  description = "The external IP address of the provisioned ingress controller load balancer."
}