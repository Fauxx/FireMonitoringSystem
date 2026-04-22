variable "require_secrets" {
  type    = bool
  default = false
}

variable "do_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "github_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "github_owner" {
  type    = string
  default = ""
}

variable "github_repo" {
  type    = string
  default = ""
}

variable "ssh_key_ids" {
  type    = list(string)
  default = []
}

variable "do_ssh_host_fingerprint" {
  type    = string
  default = ""
}

variable "region" {
  type    = string
  default = "sgp1"
}

variable "droplet_size" {
  type    = string
  default = "s-1vcpu-1gb"
}

variable "droplet_image" {
  type    = string
  default = "docker-20-04"
}

variable "allow_ssh_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0", "::/0"]
}

