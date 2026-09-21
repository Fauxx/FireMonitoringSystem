locals {
  project_id   = var.gcp_project_id
  sa_name      = "sa-github-actions-dev"
  wif_pool_id  = "github-actions"
  wif_provider = "github-oidc"
  gh_org       = "Fauxx"
  gh_repo      = "FireMonitoringSystem"
}

# ── CI Service Account
resource "google_service_account" "github_actions" {
  project      = local.project_id
  account_id   = local.sa_name
  display_name = "GitHub Actions CI — FireMonitoringSystem Dev"
}

# ── Workload Identity Pool
resource "google_iam_workload_identity_pool" "github" {
  project                   = local.project_id
  workload_identity_pool_id = local.wif_pool_id
  display_name              = "GitHub Actions WIF Pool"
}

resource "google_iam_workload_identity_pool_provider" "github_oidc" {
  project                            = local.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = local.wif_provider

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository == '${local.gh_org}/${local.gh_repo}'"
}

resource "google_service_account_iam_binding" "wif_binding" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${local.gh_org}/${local.gh_repo}",
  ]
}

# ── IAM Roles
resource "google_project_iam_member" "ci_roles" {
  for_each = toset([
    "roles/container.admin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/artifactregistry.admin",
    "roles/secretmanager.admin",
    "roles/storage.objectAdmin",
    "roles/dns.admin",
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.serviceAccountUser",
    "roles/cloudsql.admin",
    "roles/resourcemanager.projectIamAdmin",
  ])
  project = local.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ── GitHub Environment: gke-dev
module "github_secrets" {
  source                             = "../../../modules/shared/github-secrets"
  github_environment                 = "gke-dev"
  github_repository                  = local.gh_repo
  gcp_project_id                     = local.project_id
  gcp_workload_identity_provider     = google_iam_workload_identity_pool_provider.github_oidc.name
  gcp_service_account                = google_service_account.github_actions.email
  tf_state_bucket                    = "firemonitoring-tfstate"
  gitops_repo_url                    = var.gitops_repo_url
  github_app_id                      = var.github_app_id
  github_app_installation_id         = var.github_app_installation_id
  github_app_private_key             = var.github_app_private_key
  cloudflare_tunnel_credentials_json = var.cloudflare_tunnel_credentials_json
}
