variable "azure_subscription_id" {
  type        = string
  description = "The Azure Subscription ID"
}

variable "azure_tenant_id" {
  type        = string
  description = "The Azure AD Tenant ID"
}

variable "azure_client_id" {
  type        = string
  description = "The Azure Client ID"
}

variable "azure_client_secret" {
  type        = string
  sensitive   = true
  description = "The Azure Client Secret for bootstrapping"
}

variable "github_token" {
  type        = string
  sensitive   = true
  description = "GitHub PAT for provisioning repository variables"
}

variable "github_owner" {
  type        = string
  description = "The GitHub Organization or User"
}

variable "github_repository" {
  type        = string
  description = "The GitHub Repository name"
}

variable "tfstate_resource_group" {
  type        = string
  default     = "rg-firemonitoring-tfstate-01"
  description = "The Azure Resource Group holding the Terraform state."
}

variable "tfstate_storage_account" {
  type        = string
  default     = "stfiremonitortfstate"
  description = "The Azure Storage Account holding the Terraform state."
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
