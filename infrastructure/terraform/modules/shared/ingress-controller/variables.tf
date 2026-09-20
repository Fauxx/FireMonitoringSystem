variable "chart_version" {
  type        = string
  description = "Helm chart version for ingress-nginx"
  default     = "4.12.0"
}

variable "additional_set_values" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "Additional Helm set values to pass to the chart"
  default     = []
}

variable "enable_gcp_backend_config" {
  type        = bool
  description = "Set true to add GCP-compatible LoadBalancer annotations"
  default     = false
}
