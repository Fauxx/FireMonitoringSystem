variable "github_environment" {
  type        = string
  description = "GitHub Actions environment name (e.g. gke-dev)"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository name (e.g. FireMonitoringSystem)"
}

variable "gcp_project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "gcp_workload_identity_provider" {
  type        = string
  description = "Full WIF provider resource name for OIDC auth"
}

variable "gcp_service_account" {
  type        = string
  description = "GCP Service Account email used by GitHub Actions"
}

variable "tf_state_bucket" {
  type        = string
  description = "GCS bucket name for Terraform remote state"
  default     = "firemonitoring-tfstate"
}

variable "gitops_repo_url" {
  type        = string
  description = "HTTPS URL of the GitOps repo (for ArgoCD)"
}

variable "github_app_id" {
  type      = string
  sensitive = true
}

variable "github_app_installation_id" {
  type      = string
  sensitive = true
}

variable "github_app_private_key" {
  type      = string
  sensitive = true
}

variable "cloudflare_tunnel_credentials_json" {
  type      = string
  sensitive = true
  default   = ""
}