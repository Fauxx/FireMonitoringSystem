data "kubernetes_service" "ingress" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = helm_release.ingress_nginx.namespace
  }
  depends_on = [helm_release.ingress_nginx]
}

output "load_balancer_ip" {
  value       = data.kubernetes_service.ingress.status.0.load_balancer.0.ingress.0.ip
  description = "Load Balancer IP for NGINX Ingress Controller"
}
