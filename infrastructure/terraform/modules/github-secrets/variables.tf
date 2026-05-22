variable "github_repository" {
  type        = string
  description = "The target GitHub repository name where the environments are configured."
}

variable "github_environment" {
  type        = string
  description = "The target environment context slot (e.g., dev, prod) within GitHub."
}

variable "github_app_id" {
  type        = string
  sensitive   = true
  description = "The unique numerical identification string of your custom GitHub App."
}

variable "github_app_installation_id" {
  type        = string
  sensitive   = true
  description = "The application installation mapping ID pointing to your target repository space."
}

variable "github_app_private_key" {
  description = "The raw GitHub App private key"
  type        = string
  sensitive   = true
}

variable "github_app_state_secret_key" {
  description = "TF Do Spaces"
  type        = string
  sensitive   = true
}

variable "github_app_state_access_key" {
  description = "The DO space access "
  type        = string
  sensitive   = true
}

variable "do_token" {
  type      = string
  sensitive = true
}