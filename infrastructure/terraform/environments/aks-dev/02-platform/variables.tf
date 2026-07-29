# ==============================================================================
# 1. CLOUD & API AUTHENTICATION (Service Principal)
# ==============================================================================

variable "azure_subscription_id" {
  type        = string
  sensitive   = true
  description = "The Azure Subscription ID used for resource provisioning."
}

variable "azure_tenant_id" {
  type        = string
  sensitive   = true
  description = "The Azure AD Tenant ID for the Service Principal."
}

variable "azure_client_id" {
  type        = string
  sensitive   = true
  description = "The Azure Service Principal Client ID used for provider authentication."
}

variable "azure_client_secret" {
  type        = string
  sensitive   = true
  description = "The Azure Service Principal Client Secret."
}

# ==============================================================================
# 2. REMOTE STATE PLUMBING (DISCOVERY)
# ==============================================================================

variable "tfstate_resource_group" {
  type        = string
  default     = "fire-monitoring-tfstate-rg"
  description = "The Azure Resource Group holding the Blob state backend."
}

variable "tfstate_storage_account" {
  type        = string
  default     = "firemonitfstate"
  description = "The Azure Storage Account holding the Terraform state."
}

variable "tfstate_container" {
  type        = string
  default     = "tfstate"
  description = "The Azure Blob container for the Terraform state."
}

variable "infra_state_key" {
  type        = string
  default     = "aks-dev/01-infra/terraform.tfstate"
  description = "The blob key path to the infrastructure state artifact."
}

variable "dns_zone_name" {
  type        = string
  description = "The domain name to register in Azure DNS (e.g., azure.fires.systems)."
}

# ==============================================================================
# 3. GITHUB APP RUNTIME INJECTION (CI CONTRACT INPUTS)
# ==============================================================================

variable "github_app_id" {
  type        = string
  sensitive   = true
  description = "The GitHub App ID injected by CI for platform-level GitHub integrations."
}

variable "github_app_installation_id" {
  type        = string
  sensitive   = true
  description = "The GitHub App installation ID injected by CI for environment-scoped operations."
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "The GitHub App private key content injected at runtime by the contract action."
}

variable "github_app_state_access_key" {
  type        = string
  sensitive   = true
  description = "Azure Storage Account access key injected by CI for remote state authentication."
}

variable "github_app_state_secret_key" {
  type        = string
  sensitive   = true
  description = "Additional secret key injected by CI if required for state authentication."
}
