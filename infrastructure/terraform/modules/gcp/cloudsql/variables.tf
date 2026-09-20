variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  description = "The GCP region for the database"
}

variable "instance_name" {
  type        = string
  description = "Name of the Cloud SQL instance"
}

variable "database_version" {
  type        = string
  default     = "POSTGRES_15"
  description = "The database version to use"
}

variable "tier" {
  type        = string
  default     = "db-f1-micro"
  description = "The machine tier for the database instance"
}

variable "database_names" {
  type        = list(string)
  description = "List of logical databases to create inside the instance"
  default     = []
}

variable "gke_service_account_email" {
  type        = string
  description = "The email of the GKE Workload Identity Service Account that needs access to the DB"
}
