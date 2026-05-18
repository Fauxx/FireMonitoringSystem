output "domain_name" {
  description = "The root domain managed by DigitalOcean"
  value       = digitalocean_domain.fire_systems.name
}

output "cluster_id" {
  description = "The ID of the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.this.id
}

output "cluster_name" {
  value       = digitalocean_kubernetes_cluster.this.name # Ensure 'this' matches your cluster resource name
  description = "The human-readable name of the DOKS cluster passed to Layer 2"
}

output "cluster_endpoint" {
  description = "The API endpoint for the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.this.endpoint
}

output "cluster_token" {
  description = "The authentication token for the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.this.kube_config[0].token
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The CA certificate for the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "vpc_id" {
  description = "The ID of the VPC created for this cluster"
  value       = digitalocean_vpc.cluster_network.id
}

output "kubeconfig_raw" {
  description = "The raw kubeconfig for the fire monitoring cluster"
  value       = digitalocean_kubernetes_cluster.this.kube_config[0].raw_config
  sensitive   = true
}