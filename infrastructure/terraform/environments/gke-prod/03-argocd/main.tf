data "google_client_config" "default" {}

data "terraform_remote_state" "infra" {
  backend = "gcs"
  config = {
    bucket = "firemonitoring-tfstate"
    prefix = "gke-prod/01-infra"
  }
}

provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.infra.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_cert)
  token                  = data.google_client_config.default.access_token
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata { name = "argocd" }
}

resource "kubernetes_namespace_v1" "fire_monitoring_dev" {
  metadata { name = "fire-monitoring-prod" }
}

resource "kubernetes_secret_v1" "repo_github_app_creds" {
  metadata {
    name      = "repo-github-app-creds"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    labels    = { "argocd.argoproj.io/secret-type" = "repository" }
  }

  type = "Opaque"
  data = {
    type                    = "git"
    url                     = var.gitops_repo_url
    githubAppID             = var.github_app_id
    githubAppInstallationID = var.github_app_installation_id
    githubAppPrivateKey     = var.github_app_private_key
  }
}

resource "kubernetes_secret_v1" "cloudflare_tunnel_credentials" {
  metadata {
    name      = "cloudflare-tunnel-credentials"
    namespace = kubernetes_namespace_v1.fire_monitoring_dev.metadata[0].name
  }

  type = "Opaque"
  data = {
    "credentials.json" = var.cloudflare_tunnel_credentials_json
  }
}

resource "kubernetes_manifest" "argocd_apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "fire-monitoring-prod"
      namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = "HEAD"
        path           = "infrastructure/k8s/overlays/prod"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace_v1.fire_monitoring_dev.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
}
