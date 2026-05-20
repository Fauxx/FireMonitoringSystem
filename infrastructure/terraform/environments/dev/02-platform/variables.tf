# ==============================================================================
# 1. CLOUD & API AUTHENTICATION
# ==============================================================================

variable "do_token" {
  type        = string
  sensitive   = true
  description = "DigitalOcean personal access token used to authenticate provider API calls for managing platform DNS and cluster lookups."
}

variable "github_token" {
  type        = string
  sensitive   = true
  description = "Personal access token used by the GitHub provider to authenticate and modify repository environments."
}

# ==============================================================================
# 2. REMOTE STATE PLUMBING (DISCOVERY)
# ==============================================================================

variable "remote_state_bucket" {
  type        = string
  description = "The name of the DigitalOcean Space S3-compatible bucket where your Layer 01 infrastructure state is stored."
}

variable "infra_state_key" {
  type        = string
  description = "The direct object path to your infrastructure state artifact (e.g., dev/01-infra/terraform.tfstate)."
}

variable "remote_state_region" {
  type        = string
  default     = "us-east-1"
  description = "The AWS S3 emulation region identifier required by DigitalOcean Spaces for API compatibility."
}

variable "remote_state_endpoint" {
  type        = string
  default     = "sgp1.digitaloceanspaces.com"
  description = "The regional endpoint URL for your active DigitalOcean Spaces storage space."
}

# ==============================================================================
# 3. GITHUB PROJECT CONTEXT
# ==============================================================================

variable "github_owner" {
  type        = string
  default     = "Fauxx"
  description = "The target owner/organization name hosting the project code on GitHub."
}

variable "github_repository" {
  type        = string
  description = "The name of the specific GitHub code repository managing the target environment."
}

# ==============================================================================
# 4. RUNNER VALIDATION HANDSHAKE (MINIMAL APPS AUTH)
# ==============================================================================

variable "github_app_id" {
  type        = string
  sensitive   = true
  description = "The unique numerical identifier of your custom GitHub App utilized by speculative workflows."
}

variable "github_app_installation_id" {
  type        = string
  sensitive   = true
  description = "The application installation mapping ID pointing to your target repository space."
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "The cryptographic, base64-encoded PEM private key utilized by your workflows to authorize short-lived pipeline runner sessions."
}

variable "github_environment" {
  type        = string
  default     = "dev"
  description = "The target deployment stage profile container slot inside GitHub (e.g., dev, prod)."
}