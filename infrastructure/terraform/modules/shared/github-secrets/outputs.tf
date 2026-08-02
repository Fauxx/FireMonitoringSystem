output "github_environment" {
  value       = github_repository_environment.this.environment
  description = "The target GitHub environment profile name where the deployment validation gates are synchronized."
}

output "secrets_synced" {
  value = [
    "APP_ID",
    "APP_INSTALLATION_ID",
    "APP_PRIVATE_KEY"
  ]
  description = "A clean list of cryptographic GitHub App key names that were securely synchronized into the environment cloud vault."
}