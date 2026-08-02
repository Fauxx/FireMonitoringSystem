variable "azure_subscription_id" {
  type = string
}

variable "azure_tenant_id" {
  type = string
}

variable "azure_client_id" {
  type = string
}

variable "tfstate_resource_group" {
  type    = string
  default = "rg-firemonitoring-tfstate-01"
}

variable "tfstate_storage_account" {
  type    = string
  default = "stfiremonitortfstate"
}

variable "tfstate_container" {
  type    = string
  default = "tfstate"
}

variable "infra_state_key" {
  type    = string
  default = "aks-prod/01-infra/terraform.tfstate"
}
