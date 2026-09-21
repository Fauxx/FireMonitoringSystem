variable "gitops_repo_url" {
  type = string
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
