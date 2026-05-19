# --- 1. Cloud Authentication ---
variable "do_token" {
  type      = string
  sensitive = true
}

variable "github_token" {
  type      = string
  sensitive = true
}

# --- 2. Remote State Plumbing (Discovery) ---
variable "remote_state_bucket" {
  type        = string
  description = "The name of your DO Space where state is kept"
}

variable "infra_state_key" {
  type        = string
  description = "The path to the Layer 01 state file (e.g., dev/01-infra/terraform.tfstate)"
}

variable "remote_state_region" {
  type    = string
  default = "us-east-1" # DigitalOcean Spaces requires this for S3 compatibility
}

variable "remote_state_endpoint" {
  type    = string
  default = "sgp1.digitaloceanspaces.com"
}

# --- 3. GitHub Project Context ---
variable "github_owner" {
  type    = string
  default = "Fauxx"
}

variable "github_repository" {
  type = string
}

# --- 4. Platform Configuration ---
variable "argocd_server" {
  type        = string
  description = "The FQDN for ArgoCD (e.g., argocd.fires.systems)"
}

variable "argocd_auth_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Optional ArgoCD auth token used for automation (set when available)"
}

# --- 5. GitHub App Credentials (Optional) ---
variable "github_app_id" {
  type        = string
  sensitive   = true
  default     = ""
  description = "GitHub App ID for CI/CD automation (optional)"
}

variable "github_app_installation_id" {
  type        = string
  sensitive   = true
  default     = ""
  description = "GitHub App Installation ID for CI/CD automation (optional)"
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "GitHub App private key (base64-encoded PEM) for CI/CD automation (optional)"
}

variable "ghcr_deploy_username" {
  type        = string
  sensitive   = false
  default     = ""
  description = "GHCR username for container registry access (optional)"
}

variable "ghcr_deploy_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "GHCR token for container registry access (optional)"
}

variable "cluster_name" {
  type        = string
  description = "The name of the DigitalOcean Kubernetes cluster"
}

