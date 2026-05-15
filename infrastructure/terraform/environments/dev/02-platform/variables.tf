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