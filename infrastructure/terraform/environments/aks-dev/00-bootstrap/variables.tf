# ==============================================================================
# Variables — 00-Bootstrap (Enterprise Edition)
# ==============================================================================

# ------------------------------------------------------------------------------
# TEMPORARY BOOTSTRAP CREDENTIALS
# These are ONLY used on the very first `terraform apply` of this layer.
# They authenticate the bootstrap run that creates the permanent OIDC identity.
# After bootstrap completes, the temporary SP that supplies these values is deleted.
# ------------------------------------------------------------------------------

variable "azure_subscription_id" {
  description = "The Azure Subscription ID where all resources will be provisioned."
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "The Microsoft Entra ID (Azure AD) Tenant ID."
  type        = string
  sensitive   = true
}

variable "azure_client_id" {
  description = "The Client ID of the TEMPORARY bootstrap Service Principal. Deleted after first run."
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "The Client Secret of the TEMPORARY bootstrap Service Principal. Deleted after first run."
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# AZURE LOCATION
# ------------------------------------------------------------------------------

variable "azure_location" {
  description = "The Azure region for all bootstrap resources. Match your AKS target region."
  type        = string
  default     = "southeastasia"
}

# ------------------------------------------------------------------------------
# STATE BACKEND — CAF Naming: st<workload><purpose>
# ------------------------------------------------------------------------------

variable "tfstate_resource_group_name" {
  description = "CAF-compliant Resource Group name for Terraform state storage."
  type        = string
  default     = "rg-firemonitoring-tfstate-01"
}

variable "tfstate_storage_account_name" {
  description = "CAF-compliant Storage Account name (max 24 chars, lowercase, no hyphens)."
  type        = string
  default     = "stfiremonitortfstate"
}

# ------------------------------------------------------------------------------
# GITHUB — OIDC TRUST CONFIGURATION
# ------------------------------------------------------------------------------

variable "github_owner" {
  description = "The GitHub organization or username that owns the target repository."
  type        = string
}

variable "github_repository" {
  description = "The GitHub repository name (without owner prefix) where environments are configured."
  type        = string
}

variable "github_token" {
  description = "A GitHub Personal Access Token or App token with 'repo' and 'admin:org' scope. Used ONLY during bootstrap to provision GitHub environments and inject variables."
  type        = string
  sensitive   = true
  ephemeral   = true # Never persisted to Terraform state
}

# ------------------------------------------------------------------------------
# GITHUB APP — ArgoCD & CI Token Generation
# These are the credentials for the GitHub App used by:
#   1. GitHub Actions (actions/create-github-app-token) to mint short-lived tokens
#   2. Argo CD to clone the GitOps repository
# ------------------------------------------------------------------------------

variable "github_app_id" {
  description = "The numeric ID of the GitHub App used for CI token generation and ArgoCD repo access."
  type        = string
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "The installation ID of the GitHub App scoped to this repository."
  type        = string
  sensitive   = true
}

variable "github_app_private_key" {
  description = "The PEM-format private key for the GitHub App. Stored encrypted in GitHub secrets."
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_app_private_key_path" {
  description = "Optional file path to the PEM-format private key for the GitHub App."
  type        = string
  default     = ""
}
