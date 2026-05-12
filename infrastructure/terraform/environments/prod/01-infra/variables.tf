variable "do_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "region" {
  type    = string
  default = "sgp1"
}

variable "doks_version" {
  type    = string
  default = ""
}

variable "doks_node_size" {
  type    = string
  default = "s-2vcpu-4gb"
}

variable "doks_node_count" {
  type    = number
  default = 2
}
