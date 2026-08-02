variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "cluster_name" {
  type        = string
  description = "AKS cluster name"
  default     = "aks-firemonitoring-dev-01"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
  default     = "1.32"
}

variable "node_vm_size" {
  type        = string
  description = "VM size for the default node pool"
  default     = "Standard_B2s"
}

variable "min_node_count" {
  type        = number
  description = "Minimum node count for the default node pool"
  default     = 1
}

variable "max_node_count" {
  type        = number
  description = "Maximum node count for the default node pool"
  default     = 3
}

variable "aks_subnet_id" {
  type        = string
  description = "Subnet ID where nodes are placed"
}

variable "service_cidr" {
  type        = string
  description = "Kubernetes service CIDR"
  default     = "10.100.0.0/16"
}

variable "dns_service_ip" {
  type        = string
  description = "Kubernetes DNS service IP"
  default     = "10.100.0.10"
}

variable "acr_id" {
  type        = string
  description = "ACR resource ID for AcrPull role assignment"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "admin_group_object_ids" {
  type        = list(string)
  description = "Entra group IDs for AKS RBAC admin access"
  default     = []
}
