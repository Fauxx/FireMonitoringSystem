variable "enabled" {
  type = bool
}

variable "github_repo" {
  type = string
}

variable "github_environment" {
  type = string
}

variable "do_ssh_host" {
  type = string
}

variable "do_ssh_host_fingerprint" {
  type = string
}

variable "kubeconfig" {
  type      = string
  sensitive = true
  default   = ""
}

variable "do_ssh_private_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "ghcr_deploy_username" {
  type      = string
  sensitive = true
  default   = ""
}

variable "ghcr_deploy_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "argocd_server" {
  type    = string
  default = ""
}

variable "argocd_auth_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "do_ssh_port" {
  type    = string
  default = "22"
}

variable "do_ssh_user" {
  type    = string
  default = "root"
}

