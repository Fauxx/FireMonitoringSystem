variable "namespace" {
  type        = string
  default     = "ingress-nginx"
  description = "The isolated namespace hosting the active Ingress Controller."
}

variable "loadbalancer_name" {
  type        = string
  default     = "doks-ingress-loadbalancer"
  description = "The name of the DigitalOcean Load Balancer."
}
