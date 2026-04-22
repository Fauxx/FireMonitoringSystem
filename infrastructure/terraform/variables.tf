variable "do_token" {
  type      = string
  sensitive = true
  default   = ""

  validation {
    condition     = !var.require_secrets || (length(trimspace(var.do_token)) > 0 && !startswith(var.do_token, "PASTE_"))
    error_message = "Set do_token to a real DigitalOcean PAT (not a placeholder)."
  }
}

variable "github_token" {
  type      = string
  sensitive = true
  default   = ""

  validation {
    condition     = !var.require_secrets || (length(trimspace(var.github_token)) > 0 && !startswith(var.github_token, "PASTE_"))
    error_message = "Set github_token to a real GitHub PAT (not a placeholder)."
  }
}

variable "github_owner" {
  type    = string
  default = ""

  validation {
    condition     = !var.require_secrets || (length(trimspace(var.github_owner)) > 0 && !startswith(var.github_owner, "PASTE_"))
    error_message = "Set github_owner to your real GitHub username or organization (not a placeholder)."
  }
}

variable "github_repo" {
  type    = string
  default = ""
}

variable "ssh_key_ids" {
  type    = list(string)
  default = []

  validation {
    condition = (
      !var.require_secrets || (
        length(var.ssh_key_ids) > 0 &&
        length(compact(var.ssh_key_ids)) == length(var.ssh_key_ids) &&
        length([for id in var.ssh_key_ids : id if startswith(id, "PASTE_")]) == 0
      )
    )
    error_message = "Set ssh_key_ids to real DigitalOcean SSH key IDs/fingerprints from your account."
  }
}

variable "do_ssh_host_fingerprint" {
  type    = string
  default = ""

  validation {
    condition     = !var.require_secrets || (length(trimspace(var.do_ssh_host_fingerprint)) > 0 && startswith(var.do_ssh_host_fingerprint, "SHA256:") && !strcontains(var.do_ssh_host_fingerprint, "PASTE_"))
    error_message = "Set do_ssh_host_fingerprint to the real server host key fingerprint in SHA256 format (e.g., SHA256:...)."
  }
}

variable "require_secrets" {
  type    = bool
  default = false
}

variable "region" {
  type    = string
  default = "sgp1"
}

variable "droplet_size" {
  type    = string
  default = "s-1vcpu-2gb"
}

variable "droplet_image" {
  type    = string
  default = "docker-20-04"
}
