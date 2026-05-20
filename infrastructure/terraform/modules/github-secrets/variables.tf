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
  type        = string
  sensitive   = true
  description = "The cryptographic PEM private key content used to authenticate pipeline action runs."
}