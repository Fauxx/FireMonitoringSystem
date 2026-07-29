# ==============================================================================
# Variables for Azure Dev 00-Bootstrap
# ==============================================================================

variable "azure_subscription_id" {
  description = "The Azure subscription ID where resources will be provisioned."
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "The Azure tenant ID for the Service Principal."
  type        = string
  sensitive   = true
}

variable "azure_client_id" {
  description = "The Azure client ID (app ID) for the Service Principal."
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "The Azure client secret (password) for the Service Principal."
  type        = string
  sensitive   = true
}

variable "azure_location" {
  description = "The Azure region to deploy resources (matches DO sgp1)."
  type        = string
  default     = "southeastasia"
}

variable "resource_group_name" {
  description = "The resource group for the state storage."
  type        = string
  default     = "fire-monitoring-tfstate-rg"
}

variable "storage_account_name" {
  description = "The globally unique name for the state storage account. No hyphens allowed."
  type        = string
  default     = "firemonitfstate"
}

variable "storage_container_name" {
  description = "The container name for terraform state within the storage account."
  type        = string
  default     = "tfstate"
}

variable "github_token" {
  description = "Personal Access Token for GitHub repository management."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "github_owner" {
  description = "The target GitHub username or organization name hosting the project."
  type        = string
}

variable "github_repository" {
  description = "The exact repository name where secrets are injected."
  type        = string
}

variable "github_environment" {
  description = "The deployment target environment name configured in GitHub."
  type        = string
  default     = "aks-prod"
}

variable "github_app_id" {
  description = "Automation App ID credentials for pipeline lifecycle tasks."
  type        = string
}

variable "github_app_installation_id" {
  description = "Installation identifier mapping the GitHub automation app to your workspace."
  type        = string
}

variable "github_app_private_key" {
  description = "Cryptographic private key authorizing the pipeline runner."
  type        = string
  sensitive   = true
}

variable "github_app_state_access_key" {
  description = "Azure Storage Account access key for state management."
  type        = string
}

variable "github_app_state_secret_key" {
  description = "Azure Storage Account secondary key for state authorization."
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "The name of the Kubernetes cluster."
  type        = string
  default     = "aks-fire-monitoring-prod"
}

variable "node_vm_size" {
  description = "VM size for the AKS worker nodes."
  type        = string
  default     = "Standard_B2s"
}

variable "node_count" {
  description = "Number of worker nodes in the default pool."
  type        = number
  default     = 2
}

variable "remote_state_container" {
  description = "Container name for remote infra state storage."
  type        = string
  default     = "tfstate"
}

variable "infra_state_key" {
  description = "Path to the infra state in the container."
  type        = string
  default     = "aks-prod/01-infra/terraform.tfstate"
}

variable "gitops_repo_url" {
  description = "The full HTTPS URL of your target GitOps repository."
  type        = string
}
