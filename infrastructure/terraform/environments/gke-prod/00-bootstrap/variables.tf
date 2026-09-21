variable "gcp_project_id" {
  type = string
}
variable "region" {
  type    = string
  default = "asia-east1"
}
variable "github_token" {
  type        = string
  sensitive   = true
  description = "Bootstrap only"
}
variable "github_app_id" {
  type      = string
  sensitive = true
}
variable "github_app_installation_id" {
  type      = string
  sensitive = true
}
variable "github_app_private_key" {
  type      = string
  sensitive = true
}
variable "cloudflare_tunnel_credentials_json" {
  type      = string
  sensitive = true
}
variable "gitops_repo_url" {
  type    = string
  default = "https://github.com/Fauxx/FireMonitoringSystem"
}
