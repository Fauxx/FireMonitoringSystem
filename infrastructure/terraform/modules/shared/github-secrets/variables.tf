variable "github_repository" {
  type        = string
  description = "The target GitHub repository name where the environments are configured."
}

variable "github_environment" {
  type        = string
  description = "The target environment context slot (e.g., aks-dev, aks-prod) within GitHub."
}

variable "github_app_id" {
  type        = string
  sensitive   = true
  description = "The unique numerical identification string of your custom GitHub App."
}

variable "github_app_installation_id" {
  type        = string
  sensitive   = true
  description = "The application installation mapping ID pointing to your target repository space."
}

variable "github_app_private_key" {
  description = "The raw GitHub App private key (PEM format)."
  type        = string
  sensitive   = true
}

variable "github_app_state_secret_key" {
  description = "Azure Storage Account secondary access key for Terraform state authentication."
  type        = string
  sensitive   = true
}

variable "github_app_state_access_key" {
  description = "Azure Storage Account primary access key for Terraform state authentication."
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "The Azure Service Principal client secret injected into the CI environment."
  type        = string
  sensitive   = true
}

# --- Infrastructure Variables ---
variable "root_domain" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "node_size" {
  type = string
}

variable "node_count" {
  type = string
}

# --- State Plumbing ---
variable "remote_state_bucket" {
  type        = string
  description = "Azure Storage container name for remote Terraform state."
}

variable "infra_state_key" {
  type        = string
  description = "Blob key path to the infrastructure state artifact."
}

# --- GitOps ---
variable "gitops_repo_url" {
  type = string
}