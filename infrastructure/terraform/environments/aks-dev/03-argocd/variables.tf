# ==============================================================================
# 1. CLOUD & API AUTHENTICATION
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
# 2. REMOTE STATE DISCOVERY (LAYER 1 INTERFACE)
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

# ==============================================================================
# 3. GITOPS REPOSITORY TARGET CONTEXT
# ==============================================================================

variable "gitops_repo_url" {
  type        = string
  description = "The full HTTPS URL of your target GitOps repository."
}

variable "gitops_repo_branch" {
  type        = string
  default     = "main"
  description = "The dedicated repository branch tracking your development manifests."
}

variable "gitops_repo_apps_path" {
  type        = string
  default     = "infrastructure/k8s/overlays/dev"
  description = "The internal file path inside the repository where the App-of-Apps manifests sit. Note: same K8s overlays are reused for Azure."
}

# ==============================================================================
# 4. CRYPTOGRAPHIC PASSPORT PRIMITIVES (SENSITIVE)
# ==============================================================================

variable "github_app_id" {
  type        = string
  sensitive   = true
  description = "The global identification string assigned to your custom GitHub App."
}

variable "github_app_installation_id" {
  type        = string
  sensitive   = true
  description = "The target deployment context mapping ID inside your repository settings."
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "The private PEM key content used locally by the cluster to request hourly tokens."
}
