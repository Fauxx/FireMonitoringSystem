# ==============================================================================
# Variables for Azure Dev 01-Infra
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
  description = "The Azure region to deploy resources."
  type        = string
  default     = "southeastasia"
}

variable "resource_group_name" {
  description = "The resource group for the AKS cluster and network resources."
  type        = string
  default     = "fire-monitoring-aks-prod-rg"
}

variable "cluster_name" {
  description = "The name of the Kubernetes cluster."
  type        = string
  default     = "aks-fire-monitoring-prod"
}

variable "node_vm_size" {
  description = "VM size for the AKS worker nodes (Budget-conscious SKU, ~$30/mo per node)."
  type        = string
  default     = "Standard_B2s"
}

variable "node_count" {
  description = "Number of worker nodes."
  type        = number
  default     = 2
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network."
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_address_prefix" {
  description = "Address prefix for the AKS subnet."
  type        = string
  default     = "10.10.1.0/24"
}

variable "kubernetes_version" {
  description = "The version of Kubernetes to use for the AKS cluster (check latest supported)."
  type        = string
  default     = "1.31"
}
