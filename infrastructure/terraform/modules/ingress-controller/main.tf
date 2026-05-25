terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15.0"
    }
  }
}

resource "kubernetes_namespace_v1" "ingress_nginx" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
  version    = "4.10.1"

  values = [yamlencode({
    controller = {
      publishService = {
        enabled = true
      }
      service = {
        annotations = {
          "service.beta.kubernetes.io/do-loadbalancer-name" = "doks-ingress-loadbalancer"
        }
      }
    }
  })]
}

data "kubernetes_service_v1" "ingress_nginx_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
  }
  depends_on = [helm_release.ingress_nginx]
}
