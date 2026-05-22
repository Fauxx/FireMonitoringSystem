# ==============================================================================
# 1. CLOUD & API AUTHENTICATION
# ==============================================================================

variable "do_token" {
  type        = string
  sensitive   = true
  description = "DigitalOcean personal access token used to authenticate provider API calls for managing platform DNS and cluster lookups."
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
# 3. GITHUB APP RUNTIME INJECTION (CI CONTRACT INPUTS)
# ==============================================================================

variable "github_app_id" {
  type        = string
  sensitive   = true
  description = "The GitHub App ID injected by CI for platform-level GitHub integrations."
}

variable "github_app_installation_id" {
  type        = string
  sensitive   = true
  description = "The GitHub App installation ID injected by CI for environment-scoped operations."
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "The GitHub App private key content injected at runtime by the contract action."
}

variable "github_app_state_access_key" {
  type        = string
  sensitive   = true
  description = "Remote state access key injected by CI runtime contract for platform layer workflows."
}

variable "github_app_state_secret_key" {
  type        = string
  sensitive   = true
  description = "Remote state secret key injected by CI runtime contract for platform layer workflows."
}
