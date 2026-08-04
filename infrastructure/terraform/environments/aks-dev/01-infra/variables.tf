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

variable "azure_location" {
  type        = string
  default     = "eastasia"
  description = "Azure region to deploy resources."
}

variable "resource_group_name" {
  type        = string
  default     = "rg-firemonitoring-dev-01"
  description = "Name of the resource group."
}

variable "vnet_cidr" {
  type        = string
  default     = "10.10.0.0/16"
  description = "CIDR block for the Virtual Network."
}

variable "aks_subnet_cidr" {
  type        = string
  default     = "10.10.1.0/24"
  description = "CIDR block for the AKS subnet."
}

variable "cluster_name" {
  type        = string
  default     = "aks-firemonitoring-dev-01"
  description = "Name of the AKS cluster."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.34"
  description = "Kubernetes version for the AKS cluster."
}

variable "node_vm_size" {
  type        = string
  default     = "Standard_B2s_v2"
  description = "VM size for the default node pool."
}

variable "min_node_count" {
  type        = number
  default     = 1
  description = "Minimum number of nodes in the node pool."
}

variable "max_node_count" {
  type        = number
  default     = 3
  description = "Maximum number of nodes in the node pool."
}

variable "service_cidr" {
  type        = string
  default     = "10.100.0.0/16"
  description = "CIDR block for Kubernetes services."
}

variable "dns_service_ip" {
  type        = string
  default     = "10.100.0.10"
  description = "IP address within the Kubernetes service address range that will be used by cluster service discovery (kube-dns)."
}

variable "acr_name" {
  type        = string
  default     = "acrfiremonitordev"
  description = "Name of the Azure Container Registry."
}

variable "key_vault_name" {
  type        = string
  default     = "kv-firemonitoring-dev-01"
  description = "Name of the Azure Key Vault."
}
