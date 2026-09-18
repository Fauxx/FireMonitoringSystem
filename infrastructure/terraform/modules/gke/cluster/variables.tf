variable "project_id"             { type = string }
variable "region"                 { type = string }
variable "cluster_name"           { type = string }
variable "network_id"             { type = string }
variable "subnet_id"              { type = string }
variable "pods_range_name"        { type = string }
variable "services_range_name"    { type = string }
variable "min_node_count" {
  type    = number
  default = 1
}
variable "max_node_count" {
  type    = number
  default = 3
}
variable "machine_type" {
  type    = string
  default = "e2-medium"
}
variable "disk_size_gb" {
  type    = number
  default = 100
}
variable "node_sa_email"          { type = string }
variable "kubernetes_version" {
  type    = string
  default = "latest"
}
