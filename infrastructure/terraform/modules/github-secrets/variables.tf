variable "enabled" {
  description = "Enable or disable secret syncing"
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "The target GitHub repository name"
  type        = string
}

variable "github_environment" {
  description = "The GitHub environment (e.g., dev, prod)"
  type        = string
}

variable "kubeconfig" {
  description = "The raw kubeconfig content for the cluster"
  type        = string
  sensitive   = true
}

variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

variable "cluster_id" {
  description = "Optional cluster id from infra layer (used by automation)"
  type        = string
  default     = ""
}

# --- Optional Variables (Defaults to empty strings) ---

variable "argocd_server" {
  type    = string
  default = ""
}

variable "argocd_auth_token" {
  type    = string
  default = ""
}

variable "ghcr_deploy_username" {
  type    = string
  default = ""
}

variable "ghcr_deploy_token" {
  type    = string
  default = ""
}

variable "github_app_id" {
  type    = string
  default = ""
}

variable "github_app_private_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "github_app_installation_id" {
  type    = string
  default = ""
}