output "environment" {
  value = "prod"
}

output "namespace" {
  value = local.namespace
}

output "argocd_namespace" {
  value = local.argocd_namespace
}
