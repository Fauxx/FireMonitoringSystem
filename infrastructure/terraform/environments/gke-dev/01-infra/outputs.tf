output "cluster_endpoint" { 
  value = module.cluster.cluster_endpoint
  sensitive = true 
}
output "cluster_ca_cert" { 
  value = module.cluster.cluster_ca_cert
  sensitive = true 
}
output "cluster_name"           { value = module.cluster.cluster_name }
output "project_id"             { value = var.project_id }
output "region"                 { value = var.region }
output "node_sa_email"          { value = google_service_account.gke_node.email }
output "workload_identity_pool" { value = module.cluster.workload_identity_pool }
