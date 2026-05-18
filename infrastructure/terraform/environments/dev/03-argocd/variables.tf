variable "remote_state_bucket" {
  description = "S3 bucket for remote state (DigitalOcean Spaces)"
  type        = string
}

variable "infra_state_key" {
  description = "Remote state key for infra layer"
  type        = string
  default     = "dev/01-infra/terraform.tfstate"
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

variable "do_token" {
  description = "DigitalOcean API token used to read the cluster configuration"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the DigitalOcean Kubernetes cluster"
  type        = string
}

# -------------------------
# GitOps Repo Settings
# -------------------------

variable "gitops_repo_url" {
  description = "GitOps repository URL (e.g., git@github.com:org/gitops-repo.git)"
  type        = string
}

variable "gitops_repo_branch" {
  description = "Target branch in GitOps repo"
  type        = string
  default     = "main"
}

variable "gitops_repo_apps_path" {
  description = "Path to applications in GitOps repo"
  type        = string
  default     = "apps"
}

variable "gitops_repo_ssh_private_key" {
  description = "SSH private key for ArgoCD repo access (base64-encoded PEM)"
  type        = string
  sensitive   = true
  default     = ""
}

# -------------------------
# GitHub Authentication (HTTPS)
# -------------------------

variable "github_username" {
  description = "GitHub username for HTTPS repo authentication (e.g., Fauxx)"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub PAT for HTTPS repo authentication"
  type        = string
  sensitive   = true
  default     = ""
}
