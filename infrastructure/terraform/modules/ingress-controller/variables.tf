variable "namespace" {
  type        = string
  default     = "ingress-nginx"
  description = "The isolated namespace hosting the active Ingress Controller."
}
