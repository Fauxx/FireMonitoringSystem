variable "github_repository" {
  type        = string
  description = "The target GitHub repository name (without owner prefix)."
}

variable "github_environment" {
  type        = string
  description = "The GitHub Actions environment name (e.g., aks-dev, aks-prod)."
}

# --- Azure Identity (OIDC — GUIDs only, not secrets) ---

variable "azure_client_id" {
  description = "The Client ID of the GitHub Actions Entra ID App Registration. Used as a non-secret environment variable."
  type        = string
}

variable "azure_tenant_id" {
  description = "The Microsoft Entra ID Tenant ID. Used as a non-secret environment variable."
  type        = string
}

variable "azure_subscription_id" {
  description = "The Azure Subscription ID. Used as a non-secret environment variable."
  type        = string
}

variable "tf_state_storage_account" {
  description = "The name of the Azure Storage Account holding Terraform remote state."
  type        = string
  default     = "stfiremonitortfstate"
}

variable "tf_state_resource_group" {
  description = "The name of the Resource Group holding the Terraform state storage account."
  type        = string
  default     = "rg-firemonitoring-tfstate-01"
}

variable "gitops_repo_url" {
  type        = string
  description = "The HTTPS URL of the GitOps repository (used by ArgoCD)."
}

# --- GitHub App (Encrypted Secrets) ---

variable "github_app_id" {
  type        = string
  sensitive   = true
  description = "The numeric ID of the GitHub App used for CI token generation and ArgoCD access."
}

variable "github_app_installation_id" {
  type        = string
  sensitive   = true
  description = "The installation ID of the GitHub App scoped to the target repository."
}

variable "github_app_private_key" {
  description = "The PEM-format private key for the GitHub App."
  type        = string
  sensitive   = true
}