variable "azure_subscription_id" {
  type      = string
  sensitive = true
}

variable "azure_tenant_id" {
  type      = string
  sensitive = true
}

variable "azure_client_id" {
  type      = string
  sensitive = true
}

variable "github_app_id" {
  type      = string
  sensitive = true
  default   = ""
}

variable "github_app_installation_id" {
  type      = string
  sensitive = true
  default   = ""
}

variable "github_app_private_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "dns_zone_name" {
  type    = string
  default = ""
}

variable "gitops_repo_url" {
  type = string
}

variable "gitops_revision" {
  type    = string
  default = "HEAD"
}

variable "argocd_version" {
  type    = string
  default = "7.9.0"
}
