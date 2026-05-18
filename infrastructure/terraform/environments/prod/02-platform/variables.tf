variable "remote_state_bucket" {
  type = string
}

variable "remote_state_region" {
  type    = string
  default = "us-east-1"
}

variable "remote_state_endpoint" {
  type    = string
  default = "sgp1.digitaloceanspaces.com"
}

variable "infra_state_key" {
  type = string
}

variable "argocd_server" {
  type = string
}

variable "do_token" {
  type      = string
  sensitive = true
}

variable "github_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "github_repository" {
  type    = string
  default = ""
}

variable "github_owner" {
  type    = string
  default = "Fauxx"
}

variable "argocd_auth_token" {
  type      = string
  sensitive = true
  default   = ""
}

# --- GitHub App Credentials (Optional) ---
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

variable "ghcr_deploy_username" {
  type      = string
  sensitive = false
  default   = ""
}

variable "ghcr_deploy_token" {
  type      = string
  sensitive = true
  default   = ""
}