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