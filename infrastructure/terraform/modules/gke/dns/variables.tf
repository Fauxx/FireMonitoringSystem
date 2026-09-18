variable "project_id" { type = string }
variable "dns_zone_name" {
  type    = string
  default = ""
}
variable "a_records" {
  type    = map(string)
  default = {}
}
