variable "do_token" {
  type        = string
  description = "DigitalOcean API token for authenticating infrastructure resources."
  sensitive   = true
}

variable "github_token" {
  type        = string
  description = "Personal Access Token for GitHub repository management."
  sensitive   = true
  ephemeral   = true
}

variable "github_owner" {
  type        = string
  description = "The target GitHub username or organization name hosting the project."
}

variable "state_bucket_name" {
  type        = string
  description = "The globally unique name for your central state tracking Spaces bucket."
  default     = "tup-firemonitoring-state"
}

variable "state_bucket_region" {
  type        = string
  description = "The native DigitalOcean region endpoint where the bucket is hosted (e.g., sgp1)."
  default     = "sgp1"
}

variable "github_environment" {
  type        = string
  description = "The deployment target environment name configured in GitHub (e.g., production)."
  default     = "production"
}

variable "github_repository" {
  type        = string
  description = "The exact repository name where secrets are injected."
}

variable "github_app_id" {
  type        = string
  description = "Automation App ID credentials for pipeline lifecycle tasks."
}

variable "github_app_installation_id" {
  type        = string
  description = "Installation identifier mapping the GitHub automation app to your workspace."
}

variable "github_app_private_key" {
  type        = string
  description = "Cryptographic private key authorizing the pipeline runner."
  sensitive   = true
}

variable "github_app_state_access_key" {
  type        = string
  description = "S3-compatible Access Key ID for state storage management."
}

variable "github_app_state_secret_key" {
  type        = string
  description = "S3-compatible Secret Access Key for state storage authorization."
  sensitive   = true
}

# --- Infrastructure Truths ---
variable "root_domain" {
  type        = string
  description = "The root domain managed by DigitalOcean"
}

variable "cluster_name" {
  type        = string
  description = "The name of the Kubernetes cluster"
}

variable "node_size" {
  type        = string
  default     = "s-4vcpu-8gb"
  description = "Droplet size for the worker nodes"
}

variable "node_count" {
  type        = number
  default     = 3
  description = "Number of worker nodes"
}

# --- State Plumbing ---
variable "remote_state_bucket" {
  type        = string
  default     = "tup-firemonitoring-state"
  description = "DigitalOcean Space name for state storage"
}

variable "infra_state_key" {
  type        = string
  default     = "prod/01-infra/terraform.tfstate"
  description = "Path to infra state"
}

# --- GitOps ---
variable "gitops_repo_url" {
  type        = string
  description = "The full HTTPS URL of your target GitOps repository."
}
