variable "remote_state_bucket" {
  description = "S3 bucket for remote state (DigitalOcean Spaces)"
  type        = string
}

variable "infra_state_key" {
  description = "Remote state key for infra layer"
  type        = string
  default     = "prod/01-infra/terraform.tfstate"
}

variable "remote_state_region" {
  description = "S3 region for remote state"
  type        = string
  default     = "us-east-1"
}

variable "remote_state_endpoint" {
  description = "S3 endpoint for remote state (e.g., sgp1.digitaloceanspaces.com)"
  type        = string
  default     = "sgp1.digitaloceanspaces.com"
}

# -------------------------
# GitOps Repo Settings
# -------------------------

variable "gitops_repo_url" {
  description = "GitOps repository URL (e.g., git@github.com:org/gitops-repo.git or https://github.com/org/repo)"
  type        = string
}

variable "gitops_repo_branch" {
  description = "Target branch in GitOps repo"
  type        = string
  default     = "main"
}

variable "gitops_repo_apps_path" {
  description = "Path to applications in GitOps repo (point to overlays/prod)"
  type        = string
  default     = "infrastructure/k8s/overlays/prod"
}

variable "gitops_repo_ssh_private_key" {
  description = "SSH private key for ArgoCD repo access (base64-encoded PEM)"
  type        = string
  sensitive   = true
  default     = ""
}
