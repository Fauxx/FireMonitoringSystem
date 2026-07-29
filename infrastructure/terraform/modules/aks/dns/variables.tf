# ==============================================================================
# Variables for Azure DNS Module
# ==============================================================================

variable "resource_group_name" {
  description = "The name of the resource group to create the DNS zone in."
  type        = string
}

variable "dns_zone_name" {
  description = "The domain name for the DNS zone."
  type        = string
}

variable "a_records" {
  description = "A map of A records to create (name -> IP address)."
  type        = map(string)
  default     = {}
}
