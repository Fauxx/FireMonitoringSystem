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

variable "do_ssh_port" {
  type    = string
  default = "22"
}

variable "do_ssh_user" {
  type    = string
  default = "root"
}

