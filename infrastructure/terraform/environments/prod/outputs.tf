output "environment" {
  value = "prod"
}

output "kubernetes_cluster_name" {
  value = digitalocean_kubernetes_cluster.this.name
}

output "kubernetes_namespace" {
  value = kubernetes_namespace.this.metadata[0].name
}

output "kubeconfig" {
  value     = local.kubeconfig
  sensitive = true
}

