variable "name" {
  type = string
}

variable "droplet_ids" {
  type = list(string)
}

variable "allow_ssh_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0", "::/0"]
}

