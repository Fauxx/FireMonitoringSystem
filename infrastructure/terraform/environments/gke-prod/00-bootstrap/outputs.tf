output "wif_provider_name" {
  value       = google_iam_workload_identity_pool_provider.github_oidc.name
  description = "Full WIF provider resource name — inject into GCP_WORKLOAD_IDENTITY_PROVIDER"
}
output "ci_sa_email" {
  value       = google_service_account.github_actions.email
  description = "CI service account email — inject into GCP_SERVICE_ACCOUNT"
}
