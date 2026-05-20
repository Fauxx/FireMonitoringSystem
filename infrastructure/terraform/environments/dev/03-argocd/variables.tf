# ==============================================================================
# 1. REMOTE STATE DISCOVERY (LAYER 1 INTERFACE)
# ==============================================================================

variable "remote_state_bucket" {
  type        = string
  description = "The name of the DigitalOcean Space bucket holding Layer 1 state data."
}

variable "infra_state_key" {
  type        = string
  description = "The storage path mapping back to your infrastructure state file."
}

variable "remote_state_region" {
  type        = string
  default     = "us-east-1"
  description = "S3 compatibility region code used by DigitalOcean Spaces."
}

variable "remote_state_endpoint" {
  type        = string
  default     = "sgp1.digitaloceanspaces.com"
  description = "Regional API server link for DigitalOcean Spaces."
}


variable "do_token" {
  type        = string
  sensitive   = true
  description = "Your personal DigitalOcean API bearer token used by doctl authentication."
}


# ==============================================================================
# 2. GITOPS REPOSITORY TARGET CONTEXT
# ==============================================================================

variable "gitops_repo_url" {
  type        = string
  description = "The full HTTPS URL of your target GitOps repository (e.g., https://github.com/owner/repo)."
}

variable "gitops_repo_branch" {
  type        = string
  default     = "dev-zet"
  description = "The dedicated repository branch tracking your development manifests."
}

variable "gitops_repo_apps_path" {
  type        = string
  default     = "infrastructure/argocd/root"
  description = "The internal file path inside the repository where the App-of-Apps manifests sit."
}

# ==============================================================================
# 3. CRYPTOGRAPHIC PASSPORT PRIMITIVES (SENSITIVE)
# ==============================================================================

variable "github_app_id" {
  type        = string
  sensitive   = true
  description = "The global identification string assigned to your custom GitHub App."
}

variable "github_app_installation_id" {
  type        = string
  sensitive   = true
  description = "The target deployment context mapping ID inside your repository settings."
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "The private PEM key content used locally by the cluster to request hourly tokens."
}