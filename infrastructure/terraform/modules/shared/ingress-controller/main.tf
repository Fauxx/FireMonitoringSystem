resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.chart_version
  namespace        = "ingress-nginx"
  create_namespace = true

  # GKE external LoadBalancer provisioning can take 5–10 min on first deploy.
  # Default Helm provider timeout is 5 min, which causes context deadline exceeded.
  timeout       = 900 # 15 minutes
  wait          = true
  wait_for_jobs = false

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "controller.config.use-proxy-protocol"
    value = "false"
  }

  set {
    name  = "controller.config.use-forwarded-headers"
    value = "true"
  }

  set {
    name  = "controller.config.proxy-real-ip-cidr"
    value = "0.0.0.0/0"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  dynamic "set" {
    for_each = var.additional_set_values
    content {
      name  = set.value.name
      value = set.value.value
    }
  }
}
