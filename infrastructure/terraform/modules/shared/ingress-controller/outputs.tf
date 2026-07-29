output "load_balancer_ip" {
  description = "The external IP address of the provisioned Load Balancer."
  value       = data.kubernetes_service_v1.ingress_nginx_controller.status[0].load_balancer[0].ingress[0].ip
}
