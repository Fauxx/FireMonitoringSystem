variable "azure_subscription_id" {
  type = string
}

variable "azure_tenant_id" {
  type = string
}

variable "azure_client_id" {
  type = string
}

variable "azure_location" {
  type    = string
  default = "westeurope"
}

variable "resource_group_name" {
  type    = string
  default = "rg-firemonitoring-prod-01"
}

variable "vnet_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "service_cidr" {
  type    = string
  default = "10.110.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "10.110.0.10"
}

variable "cluster_name" {
  type    = string
  default = "aks-firemonitoring-prod-01"
}

variable "acr_name" {
  type    = string
  default = "acrfiremonitorprod"
}

variable "key_vault_name" {
  type    = string
  default = "kv-firemonitoring-prod-01"
}

variable "min_node_count" {
  type    = number
  default = 2
}

variable "max_node_count" {
  type    = number
  default = 5
}
