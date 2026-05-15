variable "do_token" {
  description = "DigitalOcean Personal Access Token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "sgp1"
}

variable "root_domain" {
  description = "The main domain for the project (e.g., fires.systems)"
  type        = string
}

variable "cluster_name" {
  description = "The name of the Kubernetes cluster"
  type        = string
}

variable "node_size" {
  description = "Droplet size for the worker nodes"
  type        = string
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
}